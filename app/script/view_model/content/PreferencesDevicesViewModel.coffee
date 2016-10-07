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
  constructor: (element_id, @preferences_device_details, @client_repository, @conversation_repository, @cryptography_repository) ->
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

  click_on_device: (device_et) =>
    @preferences_device_details.device device_et
    amplify.publish z.event.WebApp.CONTENT.SWITCH, z.ViewModel.content.CONTENT_STATE.PREFERENCES_DEVICE_DETAILS

  click_on_verify_client: (device_et) =>
    toggle_verified = !!!@selected_device().meta.is_verified()
    changes =
      meta:
        is_verified: toggle_verified

    @client_repository.update_client_in_db @self_user().id, device_et.id, changes
    .then => @selected_device().meta.is_verified toggle_verified

  click_on_remove_device: (device_et) =>
    amplify.publish z.event.WebApp.WARNING.MODAL, z.ViewModel.ModalType.REMOVE_DEVICE,
      action: (password) =>
        @client_repository.delete_client device_et.id, password
      data: device_et.model()
