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

// TODO Only send status to API when it has changed or every 5-6 mins.

using GLib;

public class StatusDotManager : GLib.Object {

    private StatusDotAPI api;
    private StatusDotIdleDetector idle_detector;

    public signal void show_warning(string message, bool persistent = false);
    public signal void hide_warning();

    private uint tick_interval = 1000;
    private uint max_refresh_interval = 5 * 60 * 1000;

    private int64 last_updated_at = 0;

    private unowned GLib.Settings? settings;

    private StatusEnum? api_status = null;
    private StatusEnum? idle_status = null;
    private bool inside_work_hours = true;

    private int api_request_id = 0;

    public StatusDotManager(GLib.Settings? settings, string base_url, string api_key) {
        this.settings = settings;
        this.api = new StatusDotAPI(base_url, api_key);
        this.idle_detector = new StatusDotIdleDetector();

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
            check_idle_state();
            update_work_hours_state();
            return true;
        });
    }

    private void resolve_state() {
        update_work_hours_state();

        StatusEnum? chosen = null;

        if (idle_status != null) {
            chosen = idle_status;
        }
        else if (api_status != null) {
            chosen = api_status;
        }

        if (chosen == null) {
            return;
        }

        bool outside_hours_block = !inside_work_hours;
        bool enforce_offline_outside_hours = settings?.get_boolean("offline-outside-hours") ?? false;

        if (outside_hours_block && enforce_offline_outside_hours) {
            chosen = StatusEnum.OFFLINE;
        }

        bool invisible = settings?.get_boolean("statusdot-invisible") ?? true;
        if (invisible && chosen != StatusEnum.OFFLINE) {
            chosen = StatusEnum.OFFLINE;
        }

        apply_status(chosen);
    }

    private void apply_status(StatusEnum new_status, int ttl_seconds = 420) {
        if (!api.is_connection_valid()) {
            return;
        }

        var update = new StatusUpdate(new_status, ttl_seconds);
        var device_name = settings?.get_string("device-name") ?? "default";

        api.set_device_status(device_name, update, (success, status, error_message) => {
            if (success) {
                last_updated_at = status.updated_at;
                settings?.set_int("statusdot-state", (int) status.status);
                hide_warning();
            }
            else {
                show_warning(error_message, true);
            }
        });
    }

    public void refresh_from_api() {
        int64 now = GLib.get_real_time() / 1000;
        if (now - last_updated_at < max_refresh_interval) {
            return;
        }

        var device_name = settings?.get_string("device-name") ?? "default";

        int request_id = ++api_request_id;

        if (!api.is_connection_valid()) {
            api.validate_connection(device_name, (valid, error_message) => {
                if (!valid) {
                    show_warning(error_message, true);
                }
                else {
                    hide_warning();
                }
            });
            return;
        }

        api.get_device_status(device_name, (success, status, error_message) => {
            if (request_id != api_request_id) {
                return;
            }

            if (!success) {
                show_warning(error_message, true);
                return;
            }

            api_status = status.status;
            last_updated_at = status.updated_at;

            resolve_state();
        });
    }

    public void check_idle_state() {
        uint64 idle_seconds = idle_detector.get_idle_seconds();

        bool away_as_offline = settings?.get_boolean("show-away-as-offline") ?? false;
        int away_after_idle = settings?.get_int("away-after-idle") ?? 5;
        int offline_after_idle = settings?.get_int("offline-after-idle") ?? 15;

        if (idle_seconds >= offline_after_idle * 60) {
            idle_status = StatusEnum.OFFLINE;
        }
        else if (idle_seconds >= away_after_idle * 60) {
            idle_status = away_as_offline ? StatusEnum.OFFLINE : StatusEnum.AWAY;
        }
        else {
            idle_status = null;
        }

        resolve_state();
    }

    private void update_work_hours_state() {
        bool enabled = settings?.get_boolean("offline-outside-hours") ?? false;

        if (!enabled) {
            inside_work_hours = true;
            return;
        }

        int start = settings?.get_int("working-hours-start") ?? 540;
        int end   = settings?.get_int("working-hours-end") ?? 1020;

        var now = new DateTime.now_local();
        int current = now.get_hour() * 60 + now.get_minute();

        if (start < end) {
            inside_work_hours = (current >= start && current < end);
        }
        else {
            inside_work_hours = (current >= start || current < end);
        }
    }

    public void set_invisibility_mode(bool invisible) {
        settings?.set_boolean("statusdot-invisible", invisible);
        resolve_state();
    }

    public void set_show_away_as_offline(bool v) {
        settings?.set_boolean("show-away-as-offline", v);
        resolve_state();
    }

    public void set_show_busy_as_offline(bool v) {
        settings?.set_boolean("show-busy-as-offline", v);
        resolve_state();
    }

    public void set_device_name(string name) {
        settings?.set_string("device-name", name);
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

    public void set_current_status(StatusEnum status, int ttl_seconds = 420) {
        api_status = status;
        resolve_state();
        apply_status(status, ttl_seconds);
    }

    public void set_workhours_start(int v) {
        settings?.set_int("working-hours-start", v);
        resolve_state();
    }

    public void set_workhours_end(int v) {
        settings?.set_int("working-hours-end", v);
        resolve_state();
    }

    public void set_offline_outside_hours(bool v) {
        settings?.set_boolean("offline-outside-hours", v);
        resolve_state();
    }

    public void set_away_after_idle(int v) {
        settings?.set_int("away-after-idle", v);
        resolve_state();
    }

    public void set_offline_after_idle(int v) {
        settings?.set_int("offline-after-idle", v);
        resolve_state();
    }
}