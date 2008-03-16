#!/usr/bin/env ruby
#
#  Copyright (c) 2007 Ritchie Young. All rights reserved.
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

 

module RubySync::Connectors::MemoryAssociationTracking
        
  # Returns an instance based hash association=>path
  def paths_by_association
    @paths_by_association ||= {}
  end
  
  # Returns an instance based hash path=>{context=>key}
  def associations_by_path
    @assocications_by_path ||= {}
  end
  
  # Store association for the given path
  def associate association, path
    paths_by_association[association.to_s] = path
    associations_for(path)[association.context] = association.key
  end
      
  def path_for_association association
    paths_by_association[association.to_s]
  end
      
  def associations_for path
    associations_by_path[path] ||= {}
  end

  def remove_association association
    path = paths_by_association[association]
    if path
      paths_by_association.delete(association)
      associations_for(path).delete(association.context)
    end
  end

  def association_key_for context, path
    associations_for(path)[context]
  end

  def remove_associations
    @paths_by_association = nil
    @associations_by_path = nil
  end
end
