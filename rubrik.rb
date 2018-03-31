$LOAD_PATH.unshift File.expand_path('../lib/', __FILE__)
require 'parseoptions.rb'
require 'pp'
require 'getCreds.rb'
require 'json'
require 'csv'
require 'uri'
require 'restCall.rb'

date = DateTime.now.strftime('%Y-%m-%d.%H-%M-%S')


class DateTime
  def to_time
    Time.local( *strftime( "%Y-%m-%d %H:%M:%S" ).split )
  end
end

class Hash
   def Hash.nest
     Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
   end
end

def bToG (b)     
  (((b.to_f/1024/1024/1024) * 100) / 100) 
end

def writecsv(row,hdr)
  if csv_exists?
    CSV.open(Options.outfile, 'a+') { |csv| csv << row }
  else
    CSV.open(Options.outfile, 'wb') do |csv|
      csv << hdr
      csv << row
    end
  end
end

def csv_exists?
  @exists ||= File.file?(Options.outfile)
end

def to_g (b)     
  (((b.to_i/1024/1024/1024) * 100) / 100).round 
end

# BEGIN
Creds = getCreds();
Begintime=Time.now
Logtime=Begintime.to_i

# Global options
Options = ParseOptions.parse(ARGV)
s = Options.n
vers=restCall(s ,"/api/v1/cluster/me",'','get')["version"]
puts "Rubrik CDM Version #{vers}" 

if Options.envision then
  # Get the ID of the specified report
  require 'pathname'
  pn = Pathname.new("data/"+s)
  if pn.exist? 
    dataset = JSON.parse(File.read('data/'+s))
  else
    dataset = Array.new
  end
  # VERS
  if vers.start_with?('4.1') then 
    h=restCall(s ,"/api/internal/report?name=#{Options.envision}",'','get')
  else 
    h=restCall(s ,"api/internal/report?search_value=#{Options.envision}",'','get')
  end
  h['data'].each do |r|
    if r['name'] == Options.envision then
      # Get the headers for the report
      end_date = Time.at(Time.now.to_i).to_date
      seven_day = Time.at((Time.now - (60*60*24*7)).to_i).to_date
      fourteen_day = Time.at((Time.now - (60*60*24*14)).to_i).to_date
      seven_days = (seven_day..end_date).map(&:to_s)
      fourteen_days = (fourteen_day..end_date).map(&:to_s)
      last = false
      done = false
      page=0
      puts "Getting report data from Rubrik"
      until done 
        # See if we're making a fresh call or paging call
        if last
          page += 1 
          if vers.start_with?('4.1') then 
            call = "/api/internal/report/#{r['id']}/table"
            payload = { "limit": 1000, "sortBy": "StartTime", "sortOrder": "desc" , "cursor": "#{last}"}
          else 
            go="after_id=#{last}"
            call = "/api/internal/report/#{r['id']}/table?limit=1000&sort_attr=QueuedTime&sort_order=desc&#{go}"
          end
          print "."
        else
          page += 1 
          if vers.start_with?('4.1') then 
            call = "/api/internal/report/#{r['id']}/table"
            payload = { "limit": 1000, "sortBy": "StartTime", "sortOrder": "desc" }
          else
            call = "/api/internal/report/#{r['id']}/table?limit=1000&sort_attr=QueuedTime&sort_order=desc"
          end
          print "."
        end
        puts
        if vers.start_with?('4.1') then 
          o=restCall(s ,call,payload,'post')
        else
          o=restCall(s ,call,'','get')
        end
        hdr = o['columns']
        # Iterate results and see if it's in range, add it to data_set
        o['dataGrid'].each do |line|
          zip = hdr.zip(line).to_h
          q_date = zip['StartTime'].gsub(/(\d{4}\-\d{2}\-\d{2}).*$/,'\1')
          if seven_days.include?(q_date)
            dataset << line
          end
        end 
        # See if we need to grab more results
        if vers.start_with?('4.1') then 
          last = o['cursor']
        else
          last = o['lastId']
        end
        if o['hasMore'] == false
          done=1
        end
      end
      puts "Updating data store"


      # save the data to pstore
      dataset = dataset.uniq
      dataset = dataset.sort_by { |k| k[10] }.reverse
      puts "Assembling Output"
 # Here

      #do stuff with datasets
      if Options.outfile then 
        puts hdr.to_csv
        dataset.each do |e|
          writecsv(e,hdr)
        end
      elsif Options.html then
        issues = Hash.new
        summary = Hash.new
        dataset.each do |line|
          zip = hdr.zip(line).to_h
          #next unless zip['TaskStatus'] == "Failed"
          next unless Time.parse(zip['StartTime']).to_i > ((Time.now.to_i)-(14*86400))
          unless issues.key?(zip['TaskType'])
            issues[zip['TaskType']] = Hash.new
          end
          unless issues[zip['TaskType']].key?(zip['ObjectName'])
            issues[zip['TaskType']][zip['ObjectName']] = Hash.new
          end
          unless issues[zip['TaskType']][zip['ObjectName']].key?(zip['TaskStatus'])
             issues[zip['TaskType']][zip['ObjectName']][zip['TaskStatus']] = 1
          else
             issues[zip['TaskType']][zip['ObjectName']][zip['TaskStatus']] += 1
          end
          unless issues[zip['TaskType']][zip['ObjectName']].key?('Succeeded')
            issues[zip['TaskType']][zip['ObjectName']]['Succeeded'] = 0
          end
          unless issues[zip['TaskType']][zip['ObjectName']].key?('Failed')
            issues[zip['TaskType']][zip['ObjectName']]['Failed'] = 0
          end
          # date/sla successes, failures, percent, size
          q_date = zip['StartTime'].gsub(/(\d{4}\-\d{2}\-\d{2}).*$/,'\1')
          unless summary.key?(q_date)
            summary[q_date] = Hash.new
          end
          unless summary[q_date].key?(zip['SlaDomain'])
            summary[q_date][zip['SlaDomain']] = Hash.new
          end
          unless summary[q_date][zip['SlaDomain']].key?(zip['TaskStatus'])
            summary[q_date][zip['SlaDomain']][zip['TaskStatus']] = 1
          else
            summary[q_date][zip['SlaDomain']][zip['TaskStatus']] += 1
          end
          unless summary[q_date][zip['SlaDomain']].key?("Failed")
            summary[q_date][zip['SlaDomain']]["Failed"] = 0
          end
          unless summary[q_date][zip['SlaDomain']].key?("Succeeded")
            summary[q_date][zip['SlaDomain']]["Succeeded"] = 0
          end
          unless summary[q_date][zip['SlaDomain']].key?('DataTransferred')
            summary[q_date][zip['SlaDomain']]['DataTransferred'] = zip['DataTransferred']
          else
            summary[q_date][zip['SlaDomain']]['DataTransferred'] = ((zip['DataTransferred']).to_i + (summary[q_date][zip['SlaDomain']]['DataTransferred']).to_i) 
          end
        end  

        # Begin HTML Formatting for Title
        html = ''
        html << "<html>"
        html << "<table width=1000>"
        html << "<tr><td align=center><font size='+2'>Rubrik Daily Report</font></td></tr>"
        html << "<tr><td align=center>#{Time.now.strftime('%b %d, %Y')}</td></tr>"
        html << "<tr><td align=center><hr></td></tr>"
        html << "</table>"

        # Set Table Output for 24 hour report 
        data_req = ["ObjectName", "TaskType", "SlaDomain", "TaskStatus", "StartTime", "EndTime", "Duration", "14DaySuccessRate"]
        html << "<table width=1000>"
        html << "<tr border=1><td colspan=#{data_req.count} align=center border=1><b>Job Failures (Last 24 Hours)</b></td></tr>"
        data_req.each do |h|
          html << "<th>#{h}</th>"
        end
        dataset.each do |line|
          begin
          zip = hdr.zip(line).to_h
          next unless zip['TaskStatus'] == "Failed"
          next unless Time.parse(zip['StartTime']).to_i > ((Time.now.to_i)-86400)
          zip['14DaySuccessRate'] =  (((issues[zip['TaskType']][zip['ObjectName']]['Succeeded'] / (issues[zip['TaskType']][zip['ObjectName']]['Succeeded']+issues[zip['TaskType']][zip['ObjectName']]['Failed'])).to_i)*100).to_s + "%"
          html << "<tr>" 
          data_req.each do |r|
            if r == "Duration"
              o = Time.at(zip[r].to_i/1000).utc.strftime("%H:%M:%S")
            else
              o = zip[r]
            end
            html << "<td align=center>#{o}</td>"
          end
          html << "<tr>"
          rescue
            print "Tried to divide #{issues[zip['TaskType']][zip['ObjectName']]['Succeeded']} by #{(((issues[zip['TaskType']][zip['ObjectName']]['Succeeded']+issues[zip['TaskType']][zip['ObjectName']]['Failed'])).to_i)*100} and failed.\n" 
            pp(zip)
          end
        end
        html << "</table>"
       
        # Summary Table
        data_req = ["Day", "SlaDomain", "Success", "Failure", "SuccessRate", "DataTransferred"]
        html << "<table width=1000>"
        html << "<tr><td colspan=#{data_req.count} align=center><hr></td></tr>"
        html << "<tr><td colspan=#{data_req.count} align=center><b>7 Day Success Rates</b></td></tr>"
        data_req.each do |h|
          html << "<th align=center>#{h}</th>"
        end
        summary.keys.each do |sum|
          summary[sum].keys.sort.each do |sla|
            if  summary[sum][sla]['Succeeded'].to_f > 0
              calc = ((((summary[sum][sla]['Succeeded'].to_f)/((summary[sum][sla]['Succeeded'].to_f)+(summary[sum][sla]['Failed'].to_f)))*100).to_i).to_s + "%"
            else
              calc = "0%"
            end
            html << "<tr>"
            html << "<td align=center>#{sum}</td>" 
            html << "<td align=center>#{sla}</td>" 
            html << "<td align=center>#{summary[sum][sla]['Succeeded']}</td>" 
            html << "<td align=center>#{summary[sum][sla]['Failed']}</td>" 
            html << "<td align=center>#{calc}</td>" 
            html << "<td align=center>#{(((summary[sum][sla]['DataTransferred'].to_f)/1024/1024/1024).round(2)).to_s + "GB"}</td>" 
            html << "</tr>"
          end
        end
        html << "</table>"
        html << "</html>"
        if Options.toEmail
          begin 
            require 'mail'
            Mail.deliver do
              from    "#{Options.fromEmail}" 
  	      to      "#{Options.toEmail}" 
              subject "[Rubrik] #{Time.now.strftime('%b %d, %Y')} Daily Report for #{s}"
   	      html_part do
    	        content_type 'text/html; charset=UTF-8'
    	        body html
  	      end
            end
          puts "Sent report to #{Options.toEmail}, from #{Options.fromEmail}"
          rescue Exception => e
            puts "Could not send email " + e.message
          end
        end
        begin
          IO.write("reports/#{s}-#{date}.html",html)
        rescue
          puts "Couldn't write file reports/#{s}-#{date}.html"
        end
      end
      begin
        File.write("data/"+s, dataset.to_json)
      rescue
        puts "Could not write data cache 'data/#{s}'"
      end 
    end
  end
end

if Options.login then
   require 'getToken.rb'
end
