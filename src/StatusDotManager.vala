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

using GLib;

public class StatusDotManager : GLib.Object {

    private StatusDotAPI api;

    public signal void disconnected();
    public signal void connected();
    public signal void updated();
    public signal void warning(string message);

    private string device_name = "test";
    private uint refresh_interval_ms = 5 * 60 * 1000; // 5 minutes in milliseconds
    private bool was_connected = true;
    private int last_updated_at;

    private unowned GLib.Settings? settings;

    public StatusDotManager(StatusDotAPI api, GLib.Settings? settings) {
        this.api = api;
        this.settings = settings;

        refresh_from_api();

        Timeout.add(refresh_interval_ms, () => {
            refresh_from_api();
            return true;
        });
    }

    public void set_api(StatusDotAPI api) {
        this.api = api;
        refresh_from_api();
    }

    public void refresh_from_api() {
        api.get_device_status.begin(device_name, (obj, res) => {
            try {
                var result = api.get_device_status.end(res);

                //status = result.status;
                last_updated_at = result.updated_at;

                updated();

                if (!was_connected) {
                    connected();
                    was_connected = true;
                }
            } catch (Error e) {
                //warning("Failed to refresh status: %s", e.message);

                if (was_connected) {
                    disconnected();
                    was_connected = false;
                }
            }
        });
    }

    public void set_current_status(StatusEnum new_status, int ttl_seconds = 420) {
        var update = new StatusUpdate(new_status, ttl_seconds);

        api.set_device_status.begin(device_name, update, (obj, res) => {
            try {
                api.set_device_status.end(res);

                //status = new_status;
                last_updated_at = (int) new DateTime.now_utc().to_unix();

                updated();

            } catch (Error e) {
                //warning("Failed to set status: %s", e.message);
            }
        });
    }
    
    public void set_base_url(string base_url) {
        settings?.set_string("statusdot-api-baseurl", base_url);
    }

    public void set_device_name(string device_name) {
        this.device_name = device_name;
        settings?.set_string("device-name", device_name);
    }

    public void set_invisibility_mode(bool invisible) {
        settings?.set_boolean("statusdot-invisible", invisible);
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
    }

    public void set_show_busy_as_offline(bool show_busy_as_offline) {
        settings?.set_boolean("show-busy-as-offline", show_busy_as_offline);
    }

    public void set_away_after_idle(int away_after_idle) {
        settings?.set_int("away-after-idle", away_after_idle);
    }

    public void set_offline_after_idle(int offline_after_idle) {
        settings?.set_int("offline-after-idle", offline_after_idle);
    }

}