require 'optparse'
require 'optparse/time'
require 'ostruct'
class ParseOptions

  CODES = %w[iso-2022-jp shift_jis euc-jp utf8 binary]
  CODE_ALIASES = { "jis" => "iso-2022-jp", "sjis" => "shift_jis" }

  def self.parse(args)
  options = OpenStruct.new

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: rubrik.rb [options]"

    opts.separator ""
    opts.separator "Specific options:"
    opts.on('-l', '--login', "Perform no operations but return authentication token") do |login|
      options[:login] = login;
    end
    opts.separator ""
    opts.separator "Report options:"
    opts.on('-r','--envision [string]', "Return Requested Envision Report Table Data") do |g|
      options[:envision] = g;
    end
    opts.on('--html', "Format as HTML if possible") do |g|
      options[:html] = g;
    end
    opts.on('--to', "Send to email") do |g|
      options[:toEmail] = g;
    end
    opts.on('--from', "Send from email") do |g|
      options[:fromEmail] = g;
    end
    opts.separator ""
    opts.separator "Common options:"
    opts.on('-n', '--node [Address]', "Rubrik Cluster Address/FQDN or .creds name") do |node|
      options[:n] = node;
    end
    opts.on('-u', '--username [username]',"Rubrik Cluster Username") do |user|
      options[:u] = user;
    end
    opts.on('-p', '--password [password]', "Rubrik Cluster Password") do |pass|
      options[:p] = pass;
    end
    opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
    end
  end
  opt_parser.parse!(args)
   options
  end
end
