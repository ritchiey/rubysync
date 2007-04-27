#!/usr/bin/env ruby
#
#  Created by Ritchie Young on 2007-04-24.
#  Copyright (c) 2007. All rights reserved.

class PeopleController < ApplicationController
  
  scaffold 'Person'
  
  def show
    @person = Person.find params[:id]
  end
  
end