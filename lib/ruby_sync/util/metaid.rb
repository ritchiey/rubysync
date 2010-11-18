#!/usr/bin/env ruby

# This file is extracted from an article published by "why the lucky stiff" at
# http://ruby-metaprogramming.rubylearning.com/html/seeingMetaclassesClearly.html
#
# Hopefully Why will publish a meta-programming gem later and RubySync can
# just make that a dependency.
#

class Object
   # The hidden singleton lurks behind everyone
   def metaclass; class << self; self; end; end
   def meta_eval(&blk); metaclass.instance_eval(&blk); end

   # Adds methods to a metaclass
   def meta_def name, &blk
     meta_eval { define_method name, &blk }
   end

   # Defines an instance method within a class
   def class_def name, &blk
     class_eval { define_method name, &blk }
   end
end
