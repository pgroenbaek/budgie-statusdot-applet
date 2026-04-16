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
    private bool is_connection_valid = false;

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

    public void validate_connection() throws GLib.Error {
        try {
            GLib.Uri.parse(base_url, GLib.UriFlags.NONE);
        } catch (GLib.Error e) {
            is_connection_valid = false;
            throw new GLib.Error(GLib.Quark.from_string("StatusDotAPIError"), 1, "Invalid base URL (please adjust it in settings).");
        }

        if (base_url.length < 8 || base_url.substring(0, 8) != "https://") {
            is_connection_valid = false;
            throw new GLib.Error(GLib.Quark.from_string("StatusDotAPIError"), 1, "Invalid base URL (please adjust it in settings).");
        }

        if (base_url.length < 4 || base_url.substring(base_url.length - 4, 4) != "/api") {
            is_connection_valid = false;
            throw new GLib.Error(GLib.Quark.from_string("StatusDotAPIError"), 1, "Invalid base URL (please adjust it in settings).");
        }

        var message = new Soup.Message("GET", base_url + "/customers");
        message.request_headers.append("x-api-key", this.api_key);
        this.session.send_message(message);

        if (message.status_code == Soup.Status.UNAUTHORIZED) {
            is_connection_valid = false;
            throw new GLib.Error(GLib.Quark.from_string("StatusDotAPIError"), 2, "Invalid API key (please adjust it in settings).");
        }

        if (message.status_code == Soup.Status.OK) {
            is_connection_valid = true;
            return;
        }

        is_connection_valid = false;
        throw new GLib.Error(
            GLib.Quark.from_string("StatusDotAPIError"),
            (int) message.status_code,
            "API validation failed: %d %s".printf((int) message.status_code, message.reason_phrase)
        );
    }

    private async string request(string method, string endpoint, string? body = null) throws GLib.Error {
        if (!is_connection_valid) {
            return "{}";
        }

        string url = this.base_url + endpoint;
        var message = new Soup.Message(method, url);
        message.request_headers.append("x-api-key", this.api_key);

        if (body != null) {
            message.request_headers.append("Content-Type", "application/json");
            var body_bytes = (uint8[]) body.data;
            message.set_request("application/json", Soup.MemoryUse.COPY, body_bytes);
        }

        string response = null;

        var loop = new GLib.MainLoop();
        this.session.queue_message(message, (session, message) => {
            if (message.status_code != Soup.Status.OK &&
                message.status_code != Soup.Status.CREATED)
            {
                loop.quit();
                throw new GLib.Error(
                    GLib.Quark.from_string("StatusDotAPIError"),
                    (int) message.status_code,
                    "HTTP request failed: %d %s".printf((int) message.status_code, message.reason_phrase)
                );
            }

            response = (string) message.response_body.data;
            loop.quit();
        });

        loop.run();
        return response;
    }

    private async DeviceStatus parse_device_status_object(Json.Object obj) throws GLib.Error {
        return new DeviceStatus(
            (StatusEnum) obj.get_int_member("status"),
            (int) obj.get_int_member("updated_at")
        );
    }

    public async DeviceStatus? get_device_status(string device) throws GLib.Error {
        if (!is_connection_valid) {
            return null;
        }

        string endpoint = "/api/status/%s".printf(device);

        string response = yield request("GET", endpoint);

        if (response == null || response.length == 0) {
            warning("Empty response from " + endpoint);
            return null;
        }

        var parser = new Json.Parser();

        try {
            parser.load_from_data(response, -1);
            var root = parser.get_root();

            if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
                warning("Invalid JSON structure from " + endpoint);
                return null;
            }

            var obj = root.get_object();

            return yield parse_device_status_object(obj);

        } catch (GLib.Error e) {
            warning("Failed to parse JSON from " + endpoint + ": %s".printf(e.message));
            return null;
        }
    }

    // TODO method to get /status/device

    // TODO method to set /status/device
}
