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

    public StatusEnum status { get; private set; }
    public int updated_at { get; private set; }

    private string device_id;
    private uint refresh_interval_ms = 5 * 60 * 1000; // 5 minutes in milliseconds
    private bool was_connected = true;

    public StatusDotManager(StatusDotAPI api, string device_id) {
        this.api = api;
        this.device_id = device_id;

        refresh_from_server();

        Timeout.add(refresh_interval_ms, () => {
            refresh_from_server();
            return true;
        });
    }

    public void set_api(StatusDotAPI api) {
        this.api = api;
        refresh_from_server();
    }

    public void refresh_from_server() {
        api.get_device_status.begin(device_id, (obj, res) => {
            try {
                var result = api.get_device_status.end(res);

                status = result.status;
                updated_at = result.updated_at;

                updated();

                if (!was_connected) {
                    connected();
                    was_connected = true;
                }
            } catch (Error e) {
                warning("Failed to refresh status: %s", e.message);

                if (was_connected) {
                    disconnected();
                    was_connected = false;
                }
            }
        });
    }

    public void set_status(StatusEnum new_status, int ttl_seconds = 420) {
        var update = new StatusUpdate(new_status, ttl_seconds);

        api.set_device_status.begin(device_id, update, (obj, res) => {
            try {
                api.set_device_status.end(res);

                status = new_status;
                updated_at = (int) new DateTime.now_utc().to_unix();

                updated();

            } catch (Error e) {
                warning("Failed to set status: %s", e.message);
            }
        });
    }

    public bool is_online() {
        return status == StatusEnum.ONLINE;
    }

    public bool is_away() {
        return status == StatusEnum.AWAY;
    }
}