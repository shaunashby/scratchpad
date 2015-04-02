# Puppet site.pp:
import "nodes"

# The filebucket option allows for file backups to the server
filebucket { main: server => 'puppet-01.blah.internal' }

# Back up all files to the main filebucket:
File { backup => main }

# Add a global path:
Exec { path => "/usr/bin:/usr/sbin:/bin:/sbin" }
