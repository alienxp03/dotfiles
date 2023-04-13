$LOAD_PATH << "/home/azuan/.rbenv/versions/3.2.0/lib/ruby/gems/3.2.0/gems/awesome_print-1.9.2/lib" 
require "awesome_print"
AwesomePrint.irb!

if defined?(PryByebug)
  Pry.commands.alias_command 'c', 'continue'
  Pry.commands.alias_command 'ss', 'show-source'
end
