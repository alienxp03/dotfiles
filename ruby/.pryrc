require 'amazing_print'
AmazingPrint.irb!

if defined?(PryByebug)
  Pry.commands.alias_command 'c', 'continue'
  Pry.commands.alias_command 'ss', 'show-source'
end
