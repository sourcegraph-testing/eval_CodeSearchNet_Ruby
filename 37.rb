# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Ruby SDK for convenient access of PredictionIO Output API.
#
# Author::    PredictionIO Team (support@prediction.io)
# Copyright:: Copyright (c) 2014 TappingStone, Inc.
# License::   Apache License, Version 2.0

require 'date'
require "net/http"
require 'active_support/core_ext/hash'

module PredictionIO
  # This class contains methods that interface with the PredictionIO Event
  # Server via the PredictionIO Event API using REST requests.
  #
  # Many REST request methods support optional arguments. They can be supplied
  # to these methods as Hash'es. For a complete reference, please visit
  # http://prediction.io.
  #
  # == High-performance Asynchronous Backend
  #
  # All REST request methods come in both synchronous and asynchronous flavors.
  # Both flavors accept the same set of arguments. In addition, all synchronous
  # request methods can instead accept a PredictionIO::AsyncResponse object
  # generated from asynchronous request methods as its first argument. In this
  # case, the method will block until a response is received from it.
  #
  # Any network reconnection and request retry is automatically handled in the
  # background. Exceptions will be thrown after a request times out to avoid
  # infinite blocking.
  #
  # == Installation
  # The easiest way is to use RubyGems:
  #     gem install predictionio
  #
  # == Synopsis
  # In most cases, using synchronous methods. If you have a special performance
  # requirement, you may want to take a look at asynchronous methods.
  #
  # === Instantiate an EventClient
  #     # Include the PredictionIO SDK
  #     require 'predictionio'
  #
  #     client = PredictionIO::EventClient.new(<access_key>)
  #
  # === Import a User Record from Your App (with asynchronous/non-blocking
  #     requests)
  #
  #     #
  #     # (your user registration logic)
  #     #
  #
  #     uid = get_user_from_your_db()
  #
  #     # PredictionIO call to create user
  #     response = client.aset_user(uid)
  #
  #     #
  #     # (other work to do for the rest of the page)
  #     #
  #
  #     begin
  #       # PredictionIO call to retrieve results from an asynchronous response
  #       result = client.set_user(response)
  #     rescue PredictionIO::EventClient::NotCreatedError => e
  #       log_and_email_error(...)
  #     end
  #
  # === Import a User Action (Rate) from Your App (with synchronous/blocking
  #     requests)
  #     # PredictionIO call to record the view action
  #     begin
  #       result = client.record_user_action_on_item('rate', 'foouser',
  #                                                  'baritem',
  #                                                  'rating' => 4)
  #     rescue PredictionIO::EventClient::NotCreatedError => e
  #       ...
  #     end
  class EventClient
    # Raised when an event is not created after a synchronous API call.
    class NotCreatedError < StandardError; end

    # Create a new PredictionIO Event Client with defaults:
    # - 1 concurrent HTTP(S) connections (threads)
    # - API entry point at http://localhost:7070 (apiurl)
    # - a 60-second timeout for each HTTP(S) connection (thread_timeout)
    def initialize(access_key, apiurl = 'http://localhost:7070', threads = 1, thread_timeout = 60)
      @access_key = access_key
      @http = PredictionIO::Connection.new(URI(apiurl), threads, thread_timeout)
    end

    # Returns the number of pending requests within the current client.
    def pending_requests
      @http.packages.size
    end

    # Returns PredictionIO's status in string.
    def get_status
      status = @http.aget(PredictionIO::AsyncRequest.new('/')).get
      begin
        status.body
      rescue
        status
      end
    end

    # :category: Asynchronous Methods
    # Asynchronously request to create an event and return a
    # PredictionIO::AsyncResponse object immediately.
    #
    # Corresponding REST API method: POST /events.json
    #
    # See also #create_event.
    def acreate_event(event, entity_type, entity_id, optional = {})
      h = optional.with_indifferent_access
      h.key?('eventTime') || h['eventTime'] = DateTime.now.iso8601
      h['event'] = event
      h['entityType'] = entity_type
      h['entityId'] = entity_id
      @http.apost(PredictionIO::AsyncRequest.new(event_path_with_main_params(h), h.except(:channel).to_json))
    end

    def event_path_with_main_params(options)
      result = "/events.json?accessKey=#{@access_key}"
      result += "&channel=#{options[:channel]}" if options[:channel]

      result
    end

    # :category: Asynchronous Methods
    # Asynchronously request to create a batch of event and return a
    # PredictionIO::AsyncResponse object immediately.
    #
    # Corresponding REST API method: POST /batch/events.json
    #
    # See also #acreate_event.
    def acreate_batch_event(payload)
      @http.apost(PredictionIO::AsyncRequest.new(
        "/batch/events.json?accessKey=#{@access_key}", payload.to_json
      ))
    end

    # :category: Synchronous Methods
    # Synchronously request to create an event and block until a response is
    # received.
    #
    # See also #acreate_event.
    #
    # call-seq:
    # create_event(event, entity_type, entity_id, optional = {})
    # create_event(async_response)
    def create_event(*args)
      sync_events(:acreate_event, *args)
    end

    # :category: Synchronous Methods
    # Synchronously request to create an event and block until a response is
    # received.
    #
    # See also #acreate_event.
    #
    # call-seq:
    # create_batch_event(payload)
    # create_batch_event(async_response)
    def create_batch_event(payload)
      sync_events(:acreate_batch_event, payload)
    end

    # :category: Asynchronous Methods
    # Asynchronously request to set properties of a user and return a
    # PredictionIO::AsyncResponse object immediately.
    #
    # Corresponding REST API method: POST /events.json
    #
    # See also #set_user.
    def aset_user(uid, optional = {})
      acreate_event('$set', 'user', uid, optional)
    end

    # :category: Synchronous Methods
    # Synchronously request to set properties of a user and block until a
    # response is received.
    #
    # See also #aset_user.
    #
    # call-seq:
    # set_user(uid, optional = {})
    # set_user(async_response)
    def set_user(*args)
      sync_events(:aset_user, *args)
    end

    # :category: Asynchronous Methods
    # Asynchronously request to unset properties of a user and return a
    # PredictionIO::AsyncResponse object immediately.
    #
    # properties must be a non-empty Hash.
    #
    # Corresponding REST API method: POST /events.json
    #
    # See also #unset_user.
    def aunset_user(uid, optional)
      optional.key?('properties') ||
        fail(ArgumentError, 'properties must be present when event is $unset')
      optional['properties'].empty? &&
        fail(ArgumentError, 'properties cannot be empty when event is $unset')
      acreate_event('$unset', 'user', uid, optional)
    end

    # :category: Synchronous Methods
    # Synchronously request to unset properties of a user and block until a
    # response is received.
    #
    # See also #aunset_user.
    #
    # call-seq:
    # unset_user(uid, optional)
    # unset_user(async_response)
    def unset_user(*args)
      sync_events(:aunset_user, *args)
    end

    # :category: Asynchronous Methods
    # Asynchronously request to delete a user and return a
    # PredictionIO::AsyncResponse object immediately.
    #
    # Corresponding REST API method: POST /events.json
    #
    # See also #delete_user.
    def adelete_user(uid)
      acreate_event('$delete', 'user', uid)
    end

    # :category: Synchronous Methods
    # Synchronously request to delete a user and block until a response is
    # received.
    #
    # See also #adelete_user.
    #
    # call-seq:
    # delete_user(uid)
    # delete_user(async_response)
    def delete_user(*args)
      sync_events(:adelete_user, *args)
    end

    # :category: Asynchronous Methods
    # Asynchronously request to set properties of an item and return a
    # PredictionIO::AsyncResponse object immediately.
    #
    # Corresponding REST API method: POST /events.json
    #
    # See also #set_item.
    def aset_item(iid, optional = {})
      acreate_event('$set', 'item', iid, optional)
    end

    # :category: Synchronous Methods
    # Synchronously request to set properties of an item and block until a
    # response is received.
    #
    # See also #aset_item.
    #
    # call-seq:
    # set_item(iid, properties = {}, optional = {})
    # set_item(async_response)
    def set_item(*args)
      sync_events(:aset_item, *args)
    end

    # :category: Asynchronous Methods
    # Asynchronously request to unset properties of an item and return a
    # PredictionIO::AsyncResponse object immediately.
    #
    # properties must be a non-empty Hash.
    #
    # Corresponding REST API method: POST /events.json
    #
    # See also #unset_item.
    def aunset_item(iid, optional)
      optional.key?('properties') ||
        fail(ArgumentError, 'properties must be present when event is $unset')
      optional['properties'].empty? &&
        fail(ArgumentError, 'properties cannot be empty when event is $unset')
      acreate_event('$unset', 'item', iid, optional)
    end

    # :category: Synchronous Methods
    # Synchronously request to unset properties of an item and block until a
    # response is received.
    #
    # See also #aunset_item.
    #
    # call-seq:
    # unset_item(iid, properties, optional = {})
    # unset_item(async_response)
    def unset_item(*args)
      sync_events(:aunset_item, *args)
    end

    # :category: Asynchronous Methods
    # Asynchronously request to delete an item and return a
    # PredictionIO::AsyncResponse object immediately.
    #
    # Corresponding REST API method: POST /events.json
    #
    # See also #delete_item.
    def adelete_item(uid)
      acreate_event('$delete', 'item', uid)
    end

    # :category: Synchronous Methods
    # Synchronously request to delete an item and block until a response is
    # received.
    #
    # See also #adelete_item.
    #
    # call-seq:
    # delete_item(uid)
    # delete_item(async_response)
    def delete_item(*args)
      sync_events(:adelete_item, *args)
    end

    # :category: Asynchronous Methods
    # Asynchronously request to record an action on an item and return a
    # PredictionIO::AsyncResponse object immediately.
    #
    # Corresponding REST API method: POST /events.json
    #
    # See also #record_user_action_on_item.
    def arecord_user_action_on_item(action, uid, iid, optional = {})
      optional['targetEntityType'] = 'item'
      optional['targetEntityId'] = iid
      acreate_event(action, 'user', uid, optional)
    end

    # :category: Synchronous Methods
    # Synchronously request to record an action on an item and block until a
    # response is received.
    #
    # See also #arecord_user_action_on_item.
    #
    # call-seq:
    # record_user_action_on_item(action, uid, iid, optional = {})
    # record_user_action_on_item(async_response)
    def record_user_action_on_item(*args)
      sync_events(:arecord_user_action_on_item, *args)
    end

    protected

    # Internal helper method. Do not call directly.
    def sync_events(sync_m, *args)
      if args[0].is_a?(PredictionIO::AsyncResponse)
        response = args[0].get
      else
        response = send(sync_m, *args).get
      end
      return response if response.is_a?(Net::HTTPCreated)
      begin
        msg = response.body
      rescue
        raise NotCreatedError, response
      end
      fail NotCreatedError, msg
    end
  end
end
