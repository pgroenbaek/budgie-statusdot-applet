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

using Budgie;
using Gtk;
using GLib;

public class StatusDotPlugin : Budgie.Plugin, Peas.ExtensionBase {
    public Budgie.Applet get_panel_widget(string uuid) {
        return new StatusDotApplet(uuid);
    }
}

public class StatusDotApplet : Budgie.Applet {
    private Gtk.EventBox event_box;
    private Gtk.Image? applet_icon;

    private Budgie.Popover? popover = null;
    private unowned Budgie.PopoverManager? manager = null;

    private GLib.Settings? settings;

    private string? statusdot_invisible;
    private string? statusdot_active_red;
    private string? statusdot_active_orange;
    private string? statusdot_active_green;

    public string uuid { public set; public get; }

    public StatusDotApplet(string uuid) {
        Object(uuid: uuid);

        settings = new GLib.Settings("io.grnbk.statusdotapplet");

        statusdot_invisible = "statusdot-invisible";
        statusdot_active_red = "statusdot-active-red";
        statusdot_active_orange = "statusdot-active-orange";
        statusdot_active_green = "statusdot-active-green";

        event_box = new Gtk.EventBox();
        applet_icon = new Gtk.Image.from_icon_name(get_current_mode_icon(), Gtk.IconSize.MENU);
        event_box.add(applet_icon);
        this.add(event_box);

        popover = new StatusDotWindow(event_box, settings);
        
        settings.changed["statusdot-state"].connect(() => {
            update_icon();
        });

        settings.changed["statusdot-invisible"].connect(() => {
            update_icon();
        });

        event_box.button_press_event.connect((e) => {
            if (e.button == 1) {
                if (popover.get_visible()) {
                    popover.hide();
                } else {
                    popover.show_all();
                    this.manager.show_popover(event_box);
                }
                return Gdk.EVENT_STOP;
            }
            return Gdk.EVENT_PROPAGATE;
        });

        this.show_all();
    }

    private string get_current_mode_icon() {
        bool invisible = settings.get_boolean("statusdot-invisible");
        if (invisible) {
            return statusdot_invisible;
        }

        int value = settings.get_int("statusdot-state");
        StatusEnum status = (StatusEnum) value;
        var state_icon = statusdot_active_red;

        switch (status) {
            case StatusEnum.OFFLINE:
                state_icon = statusdot_active_red;
                break;
            case StatusEnum.ONLINE:
                state_icon = statusdot_active_green;
                break;
            case StatusEnum.AWAY:
                state_icon = statusdot_active_orange;
                break;
            case StatusEnum.BUSY:
                state_icon = statusdot_active_red;
                break;
        }

        return state_icon;
    }

    private void update_icon() {
        if (applet_icon != null) {
            applet_icon.set_from_icon_name(get_current_mode_icon(), Gtk.IconSize.MENU);
        }
    }

    public override void update_popovers(Budgie.PopoverManager? manager) {
        manager.register_popover(event_box, popover);
        this.manager = manager;
    }

    public override bool supports_settings() {
        return true;
    }

    public override Gtk.Widget? get_settings_ui() {
        return new Label("No settings yet");
    }
}

[ModuleInit]
public void peas_register_types(TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Budgie.Plugin), typeof(StatusDotPlugin));
}