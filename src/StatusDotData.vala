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

public enum StatusEnum {
    OFFLINE = 0,
    ONLINE = 1,
    AWAY = 2,
    BUSY = 3,
}

public class StatusUpdate : GLib.Object {
    public StatusEnum status { get; set; }
    public int expiration_ttl { get; set; }

    public StatusUpdate(StatusEnum status, int expiration_ttl = 420) {
        this.status = status;
        this.expiration_ttl = expiration_ttl;
    }
}

public class DeviceStatus : GLib.Object {
    public StatusEnum status { get; set; }
    public int updated_at { get; set; }

    public DeviceStatus(StatusEnum status, int updated_at) {
        this.status = status;
        this.updated_at = updated_at;
    }
}


