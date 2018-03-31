#ruby-bits
===============


# Overview:
* Rubrik Framework for issuing Daily Reports via email for Rubrik Clusters. 4.1/4.0 Compatible.

# How to use:
```
.creds - JSON formatted configuration (or resort to including credentials in command line execution)

        {
        	"rubrik": {
                	"servers":["ip","ip",...],
                	"username": "[username]",
                	"password": "[password]"
        	}
        }

Usage: rubrik.rb [options]

Specific options:
    -l, --login                      Perform no operations but return authentication token

Report options:
    -r, --envision [string]          Return Requested Envision Report Table Data
        --html                       Format as HTML if possible
        --to                         Send to email
        --from                       Send from email

Common options:
    -n, --node [Address]             Rubrik Cluster Address/FQDN
    -u, --username [username]        Rubrik Cluster Username
    -p, --password [password]        Rubrik Cluster Password
    -h, --help                       Show this message

```

