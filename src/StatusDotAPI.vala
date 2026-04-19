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

using Soup;
using Json;
using GLib;

public class StatusDotAPI : GLib.Object {

    private Soup.Session session;
    private string base_url;
    private string api_key;
    private bool connection_valid = false;

    private delegate void RequestCallback(Soup.Session session, Soup.Message msg);

    public delegate void StatusCallback(bool success, DeviceStatus? status, string? error_message);
    public delegate void ValidationCallback(bool valid, string? error_message);

    public StatusDotAPI(string base_url, string api_key) {
        if (base_url.has_suffix("/")) {
            this.base_url = base_url.substring(0, base_url.length - 1);
        }
        else {
            this.base_url = base_url;
        }

        this.session = new Soup.Session();
        this.api_key = api_key;
    }

    private void request(string method, string endpoint, string? body, owned RequestCallback callback) {
        var request_message = new Soup.Message(method, base_url + endpoint);
        request_message.request_headers.append("x-api-key", api_key);

        if (body != null) {
            request_message.request_headers.append("Content-Type", "application/json");
            request_message.set_request(
                "application/json",
                Soup.MemoryUse.COPY,
                (uint8[]) body.data
            );
        }

        session.queue_message(request_message, (session, response_message) => {
            callback(session, response_message);
        });
    }

    private string get_json(Soup.Message message) {
        Soup.Buffer buffer = message.response_body.flatten();
        return (string) buffer.data;
    }

    public void validate_connection(string device_name, owned ValidationCallback callback) {
        if (base_url == "") {
            connection_valid = false;
            callback(false, "Base URL not set.");
            return;
        }

        if (api_key == "") {
            connection_valid = false;
            callback(false, "API key not set.");
            return;
        }

        try {
            GLib.Uri.parse(base_url, GLib.UriFlags.NONE);
        } catch (GLib.Error e) {
            connection_valid = false;
            callback(false, "Invalid base URL: Not an URL.");
            return;
        }

        if (!base_url.has_prefix("https://")) {
            connection_valid = false;
            callback(false, "Invalid base URL: Must start with 'https://'.");
            return;
        }

        if (!base_url.has_suffix("/api")) {
            connection_valid = false;
            callback(false, "Invalid base URL: Must end with '/api'.");
            return;
        }

        request("GET", "/status/" + device_name, null, (session, message) => {
            if (message.status_code == Soup.Status.CANT_RESOLVE ||
                message.status_code == Soup.Status.CANT_CONNECT ||
                message.status_code == Soup.Status.SSL_FAILED ||
                message.status_code == Soup.Status.IO_ERROR)
            {
                connection_valid = false;
                callback(false, "Network error: Cannot reach server.");
                return;
            }

            if (message.status_code == Soup.Status.UNAUTHORIZED) {
                connection_valid = false;
                callback(false, "Invalid API key.");
                return;
            }

            if (message.status_code == Soup.Status.OK) {
                connection_valid = true;
                callback(true, null);
                return;
            }

            connection_valid = false;
            callback(false, "API validation failed: %d %s".printf(
                (int) message.status_code,
                message.reason_phrase
            ));
        });
    }

    public bool is_connection_valid() {
        return connection_valid;
    }

    public void get_device_status(string device, owned StatusCallback callback) {
        request("GET", "/status/" + device, null, (session, message) => {

            if (message.status_code == Soup.Status.CANT_RESOLVE ||
                message.status_code == Soup.Status.CANT_CONNECT ||
                message.status_code == Soup.Status.SSL_FAILED ||
                message.status_code == Soup.Status.IO_ERROR)
            {
                connection_valid = false;
                callback(false, null, "Network error: Cannot reach server.");
                return;
            }

            if (message.status_code == Soup.Status.OK) {
                try {
                    var parser = new Json.Parser();

                    string json = get_json(message);

                    GLib.message(json);

                    parser.load_from_data(json, -1);

                    var obj = parser.get_root().get_object();

                    var status = new DeviceStatus(
                        (StatusEnum) obj.get_int_member("status"),
                        obj.get_int_member("updated_at")
                    );

                    callback(true, status, null);
                    return;

                } catch (Error e) {
                    callback(false, null, e.message);
                    return;
                }
            }

            callback(false, null, null);
        });
    }

    public void set_device_status(string device, StatusUpdate update, owned StatusCallback callback) {

        string json_body = "{ \"status\": %d, \"expiration_ttl\": %d }".printf(
            (int) update.status,
            update.expiration_ttl
        );

        request("POST", "/status/" + device, json_body, (session, message) => {

            if (message.status_code == Soup.Status.CANT_RESOLVE ||
                message.status_code == Soup.Status.CANT_CONNECT ||
                message.status_code == Soup.Status.SSL_FAILED ||
                message.status_code == Soup.Status.IO_ERROR)
            {
                connection_valid = false;
                callback(false, null, "Network error: Cannot reach server.");
                return;
            }

            if (message.status_code == Soup.Status.OK ||
                message.status_code == Soup.Status.CREATED) {

                try {
                    var parser = new Json.Parser();

                    string json = get_json(message);

                    parser.load_from_data(json, -1);

                    var obj = parser.get_root().get_object();

                    var status = new DeviceStatus(
                        (StatusEnum) obj.get_int_member("status"),
                        obj.get_int_member("updated_at")
                    );

                    callback(true, status, null);
                    return;

                } catch (Error e) {
                    callback(false, null, e.message);
                    return;
                }
            }

            callback(false, null, null);
        });
    }
}