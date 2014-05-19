#--
# Copyright (c) 2014, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#++

require 'rubygems'
require 'pg'
require 'pg_extra'
require 'dbc'
require 'dspace_utils'

##############################################################################
# Handy DSpace PostgreSQL utilities and constants
##############################################################################
module DSpacePgUtils
  include DbConnection
  include DSpaceUtils

  # This hash shows the relationship between the DSpace handle table's
  # resource_type_id and its type. ie. RESOURCE_TYPE_IDS[type] = resource_type_id
  RESOURCE_TYPE_IDS = {
    :item	=> 2,
    :collection	=> 3,
    :community	=> 4,
  }

  # This hash shows the relationship between the DSpace handle table's
  # type and its resource_type_id. ie. RESOURCE_TYPES[resource_type_id] = type
  RESOURCE_TYPES = RESOURCE_TYPE_IDS.invert

  private

  ############################################################################
  # Yield a connection to the DSpace database. If @db_conn is nil we
  # will open and yield a new connection. Otherwise we assume that
  # @db_conn is a valid connection and we will yield it.
  ############################################################################
  def db_connect
    conn = @db_conn ? @db_conn : PG::Connection.connect2(DB_CONNECT_INFO)
    yield conn
  end

end

