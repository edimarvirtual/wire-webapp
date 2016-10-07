#
# Wire
# Copyright (C) 2016 Wire Swiss GmbH
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see http://www.gnu.org/licenses/.
#

window.z ?= {}
z.ViewModel ?= {}
z.ViewModel.content ?= {}


class z.ViewModel.content.PreferencesDevicesViewModel
  constructor: (element_id, @client_repository, @conversation_repository, @cryptography_repository) ->
    @logger = new z.util.Logger 'z.ViewModel.content.PreferencesDevicesViewModel', z.config.LOGGER.OPTIONS

    @self_user = @client_repository.self_user

    @local_fingerprint = ko.observable ''
    @current_client = @client_repository.current_client

    @location = ko.pureComputed =>
      result = ko.observable '?'
      if @current_client()?.location?
        z.location.get_location @current_client().location.lat, @current_client().location.lon, (error, location) ->
          result "#{location.place}, #{location.country_code}" if location
      return result

    # All clients except the current client
    @devices = ko.observableArray()
    @client_repository.clients.subscribe (client_ets) =>
      @devices (client_et for client_et in client_ets when client_et.id isnt @current_client().id)

  _update_fingerprints: =>
    @cryptography_repository.get_session @self_user().id, @selected_device().id
    .then (cryptobox_session) =>
      @fingerprint_remote cryptobox_session.fingerprint_remote()
      @fingerprint_local cryptobox_session.fingerprint_local()

  click_on_device: => return

  click_on_verify_client: =>
    toggle_verified = !!!@selected_device().meta.is_verified()
    client_id = @selected_device().id
    user_id = @self_user().id
    changes =
      meta:
        is_verified: toggle_verified

    @client_repository.update_client_in_db user_id, client_id, changes
    .then => @selected_device().meta.is_verified toggle_verified

  click_on_reset_session: =>
    reset_progress = =>
      window.setTimeout =>
        @is_resetting_session false
      , 550

    @is_resetting_session true
    @conversation_repository.reset_session @self_user().id, @selected_device().id, @conversation_repository.self_conversation().id
    .then -> reset_progress()
    .catch -> reset_progress()

  click_on_remove_device: (password) =>
    @client_repository.delete_client @selected_device().id, password
    .then =>
      @selected_device null
      amplify.publish z.event.WebApp.ANALYTICS.EVENT, z.tracking.EventName.SETTINGS.REMOVED_DEVICE, outcome: 'success'
    .catch =>
      @logger.log @logger.levels.WARN, 'Unable to remove device'
      @remove_form_error true
      amplify.publish z.event.WebApp.ANALYTICS.EVENT, z.tracking.EventName.SETTINGS.REMOVED_DEVICE, outcome: 'fail'
