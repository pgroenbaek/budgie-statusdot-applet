/*
 * This file is part of the Budgie Desktop Statusdot Applet.
 *
 * Copyright (C) 2026 Peter Grønbæk Andersen <peter@grnbk.io>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

// TODO:
// - if status is set when invisible, dont change it to anything but OFFLINE
// - Outside hours range
// - Invisible outside hours
// - Idle time settings and duration detection

using GLib;

public class StatusDotManager : GLib.Object {

    private StatusDotAPI api;

    public signal void show_warning(string message, bool persistent = false);
    public signal void hide_warning();

    private uint tick_interval = 1 * 60 * 1000; // 1 minute in milliseconds
    private uint max_refresh_interval = 5 * 60 * 1000; // 5 minutes in milliseconds

    private int64 last_updated_at = 0;
    private bool last_outside_hours = false;

    private unowned GLib.Settings? settings;

    public StatusDotManager(GLib.Settings? settings, string base_url, string api_key) {
        this.settings = settings;
        this.api = new StatusDotAPI(base_url, api_key);

        var device_name = settings?.get_string("device-name") ?? "default";

        api.validate_connection(device_name, (valid, error_message) => {
            if (valid) {
                hide_warning();
            }
            else {
                show_warning(error_message, true);
            }
        });

        Timeout.add(tick_interval, () => {
            refresh_from_api();
            check_outside_hours();
            check_idle_duration();
            return true;
        });
    }

    public void refresh_from_api() {
        int64 now = GLib.get_real_time () / 1000;
        int64 elapsed = now - last_updated_at;

        if (elapsed < max_refresh_interval) {
            return;
        }

        var device_name = settings?.get_string("device-name") ?? "default";

        if (!api.is_connection_valid()) {
            api.validate_connection(device_name, (valid, error_message) => {
                if (valid) {
                    hide_warning();
                }
                else {
                    show_warning(error_message, true);
                }
            });
            return;
        }

        api.get_device_status(device_name, (success, status, error_message) => {
            if (success) {
                last_updated_at = status.updated_at;
                var remote_status = status.status;
                
                bool invisible = settings?.get_boolean("statusdot-invisible") ?? true;
                if (!invisible) {
                    
                    set_current_status(remote_status);
                }
                else if (invisible && remote_status != StatusEnum.OFFLINE) {
                    set_current_status(StatusEnum.OFFLINE);
                }

                hide_warning();
            }
            else {
                show_warning(error_message, true);
            }
        });
    }

    public void check_outside_hours() {
        // TODO
    }

    public void check_idle_duration() {
        // TODO
    }

    public void set_current_status(StatusEnum new_status, int ttl_seconds = 420) {
        if (!api.is_connection_valid()) {
            return;
        }

        var update = new StatusUpdate(new_status, ttl_seconds);
        var device_name = settings?.get_string("device-name") ?? "default";

        api.set_device_status(device_name, update, (success, status, error_message) => {
            if (success) {
                last_updated_at = status.updated_at;
                settings?.set_int("statusdot-state", (int) status.status);
            }
            else {
                show_warning(error_message, true);
            }
        });
    }

    public void set_api_info(string base_url, string api_key) {
        settings?.set_string("statusdot-api-baseurl", base_url);

        api = new StatusDotAPI(base_url, api_key);

        var device_name = settings?.get_string("device-name") ?? "default";

        api.validate_connection(device_name, (valid, error_message) => {
            if (valid) {
                hide_warning();
            }
            else {
                show_warning(error_message, true);
            }
        });
    }

    public void set_device_name(string device_name) {
        settings?.set_string("device-name", device_name);
    }

    public void set_invisibility_mode(bool invisible) {
        settings?.set_boolean("statusdot-invisible", invisible);

        StatusEnum current_status = (StatusEnum) settings.get_int("statusdot-state");
        if (invisible && current_status != StatusEnum.OFFLINE) {
            set_current_status(StatusEnum.OFFLINE);
        }
    }

    public void set_workhours_start(int workhours_start) {
        settings?.set_int("working-hours-start", workhours_start);
    }

    public void set_workhours_end(int workhours_end) {
        settings?.set_int("working-hours-end", workhours_end);
    }

    public void set_invisible_outside_hours(bool invisible_outside_hours) {
        settings?.set_boolean("invisible-outside-hours", invisible_outside_hours);
    }

    public void set_show_away_as_offline(bool show_away_as_offline) {
        settings?.set_boolean("show-away-as-offline", show_away_as_offline);

        StatusEnum current_status = (StatusEnum) settings.get_int("statusdot-state");
        if (current_status == StatusEnum.AWAY) {
            set_current_status(StatusEnum.OFFLINE);
        }
    }

    public void set_show_busy_as_offline(bool show_busy_as_offline) {
        settings?.set_boolean("show-busy-as-offline", show_busy_as_offline);

        StatusEnum current_status = (StatusEnum) settings.get_int("statusdot-state");
        if (current_status == StatusEnum.BUSY) {
            set_current_status(StatusEnum.OFFLINE);
        }
    }

    public void set_away_after_idle(int away_after_idle) {
        settings?.set_int("away-after-idle", away_after_idle);
    }

    public void set_offline_after_idle(int offline_after_idle) {
        settings?.set_int("offline-after-idle", offline_after_idle);
    }
}