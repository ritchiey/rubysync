# Copyright (c) 2007 Ritchie Young. All rights reserved.
# Copyright (c) 2010 Nowhere Man
# 
# This file is part of RubySync.
# 
# RubySync is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
# 
# RubySync is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with RubySync; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA

#TODO implement a method missing mechanism to chain callbacks and even sub_callbacks without the help of Arrays
#e.g. #callback_chaining(['match_value1','match_value2']).downcase.replace_special_chars { |sub_callback| sub_callback.reverse_words.upcase }.replace_punctuations('*')
module RubySync::CallbackChain

  #TODO global (sub_)callbacks_options, recursive callbacks
  def callback_chaining(tokens, callbacks = [], sub_callbacks = [], &block)
    callbacks.each_with_index do |callback, i|
      tokens.dup.map_with_index! do |token, token_index|
        original_token = token.dup
        callback_options = {:token_index => token_index}
        token =
          if callback.is_a?(Proc)
          callback.call(token)
        elsif callback.is_a?(::Array)
          callback_options.merge!(callback.extract_options)
          if callback.first.is_a?(Proc)
            callback.first.call(token)
          elsif token.is_a?(::Array)
            token.pluck(callback.first, *callback.without_options.from(1))
          else
            token.send(callback.first, *callback.without_options.from(1))
          end
        else
          if token.is_a?(::Array)
            token.pluck(callback)
          else
            token.send(callback)
          end
        end
        callback_options[:coeff] ||= callbacks.length.to_f - i

        yield token, callback_options if block_given?
        token = original_token if callback_options[:destructive] == false
        formatted_token = token.dup
        sub_callbacks.each_with_index do |sub_callback, j|
          sub_callback_options = {:token_index => token_index}
          formatted_token =
            if sub_callback.is_a?(Proc)
            sub_callback.call(formatted_token)
          elsif sub_callback.is_a?(::Array)
            sub_callback_options.merge!(sub_callback.extract_options)
            if sub_callback.first.is_a?(Proc)
              sub_callback.first.call(formatted_token)
            elsif formatted_token.is_a?(::Array)
              formatted_token.pluck(sub_callback.first, *sub_callback.without_options.from(1))
            else
              formatted_token.send(sub_callback.first, *sub_callback.without_options.from(1))
            end
          else
            if formatted_token.is_a?(::Array)
              formatted_token.pluck(sub_callback)
            else
              formatted_token.send(sub_callback)
            end
          end
          sub_callback_options[:coeff] ||= callback_options[:coeff] - (j+1)/(sub_callbacks.length.to_f+1)
          yield formatted_token, sub_callback_options if block_given?
          formatted_token = token.dup if sub_callback_options[:destructive] == false
        end
        token
      end
    end
  end
  
end
