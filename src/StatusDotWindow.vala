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
using Gdk;
using Gtk;
using Secret;
using Budgie;

public class StatusDotWindow : Budgie.Popover {

    private Gtk.Switch? invisibility_switch = null;

    private Gtk.Stack? stack = null;
    private Gtk.Box? main_view = null;
    private Gtk.Box? settings_view = null;

    private Gtk.Label? warning_label = null;
    private Gtk.Box? warning_box = null;

    private GLib.HashTable<StatusEnum, Gtk.ToggleButton> status_toggles =
        new GLib.HashTable<StatusEnum, Gtk.ToggleButton>(GLib.direct_hash, GLib.direct_equal);

    private StatusDotManager status_manager;

    private Secret.Schema api_key_schema;

    private unowned GLib.Settings? settings;

    public StatusDotWindow(Gtk.Widget? c_parent, GLib.Settings? c_settings) {
        Object(relative_to: c_parent);
        settings = c_settings;
        get_style_context().add_class("statusdot-popover");

        api_key_schema = new Secret.Schema(
            "io.grnbk.statusdotapplet",
            Secret.SchemaFlags.NONE,
            "api-key",
            Secret.SchemaAttributeType.STRING
        );

        var container = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        container.get_style_context().add_class("container");

        /*
        Warning box
        */
        warning_box = build_warning_box();
        container.pack_start(warning_box, false, false, 0);

        /*
        Status manager.
        */
        string base_url = settings?.get_string("statusdot-api-baseurl") ?? "";
        string api_key = lookup_api_key() ?? "";

        status_manager = new StatusDotManager(c_settings, base_url, api_key);

        /*
        Stack with main and settings ui.
        */
        stack = new Gtk.Stack();
        stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        stack.set_transition_duration(250);
        stack.set_hhomogeneous(false);
        stack.set_vhomogeneous(false);

        main_view = build_main_view();
        settings_view = build_settings_view();

        stack.add_named(main_view, "main");
        stack.add_named(settings_view, "settings");

        container.pack_start(stack, true, true, 0);
        add(container);

        /*
        Events wiring.
        */
        status_manager.show_warning.connect((message, persistent) => {
            show_warning(message);
            settings.set_boolean("warning-persistent", persistent);
        });

        status_manager.hide_warning.connect(() => {
            hide_warning();
            settings.set_boolean("warning-persistent", false);
        });

        settings.changed["statusdot-state"].connect(() => {
            update_button_state();
        });

        settings.changed["show-away-as-offline"].connect(() => {
            update_button_visibility();
        });

        settings.changed["show-busy-as-offline"].connect(() => {
            update_button_visibility();
        });

        settings.changed["statusdot-invisible"].connect(() => {
            update_invisibility_mode();
        });
        
        this.show.connect(() => {
            var warning_persistent = settings.get_boolean("warning-persistent");
            var warning_text = warning_label?.get_text() ?? "";

            if (!warning_persistent || warning_text == null || warning_text == "") {
                hide_warning();
            }

            var away_button = status_toggles.lookup(StatusEnum.AWAY);
            var busy_button = status_toggles.lookup(StatusEnum.BUSY);

            bool show_away_as_offline = settings?.get_boolean("show-away-as-offline") ?? false;
            bool show_busy_as_offline = settings?.get_boolean("show-busy-as-offline") ?? false;
            away_button.set_visible(!show_away_as_offline);
            busy_button.set_visible(!show_busy_as_offline);
        });
    }

    private void update_button_visibility() {
        var away_button = status_toggles.lookup(StatusEnum.AWAY);
        var busy_button = status_toggles.lookup(StatusEnum.BUSY);

        bool show_away_as_offline = settings?.get_boolean("show-away-as-offline") ?? false;
        bool show_busy_as_offline = settings?.get_boolean("show-busy-as-offline") ?? false;
        away_button.set_sensitive(!show_away_as_offline);
        away_button.set_visible(!show_away_as_offline);
        busy_button.set_sensitive(!show_busy_as_offline);
        busy_button.set_visible(!show_busy_as_offline);
    }

    private void update_button_state() {
        StatusEnum status = (StatusEnum) settings.get_int("statusdot-state");
        status_toggles.foreach((key, button) => {
            button.set_active(key == status);
        });
    }

    private void update_invisibility_mode() {
        bool invisible = settings?.get_boolean("statusdot-invisible") ?? true;
        if (invisibility_switch.get_active() != invisible) {
            invisibility_switch.set_active(invisible);
        }
    }

    private Gtk.Button create_icon_button(string icon_name, string? label_text, bool hover_reveal = false) {
        int hbox_spacing = (label_text != null) ? 6 : 0;

        var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, hbox_spacing);
        var image = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.BUTTON);
        hbox.pack_start(image, false, false, 0);

        Gtk.Label? label = null;
        if (label_text != null) {
            label = new Gtk.Label(label_text);
            label.set_halign(Gtk.Align.START);
            hbox.pack_start(label, false, false, 0);
        }

        hbox.set_halign(Gtk.Align.CENTER);
        hbox.set_valign(Gtk.Align.CENTER);

        var button = new Gtk.Button();
        button.add(hbox);

        if (hover_reveal) {
            button.get_style_context().add_class("hover-reveal-button");
        }

        return button;
    }

    private Gtk.Box build_main_view() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

        var grid = new Gtk.Grid();
        grid.set_hexpand(true);
        grid.set_halign(Gtk.Align.FILL);
        grid.set_row_spacing(6);
        grid.set_column_spacing(12);
        grid.set_margin_bottom(6);

        var invisibility_label = new Gtk.Label(_("Invisibility Mode"));
        invisibility_label.set_halign(Gtk.Align.START);
        invisibility_label.set_hexpand(true);

        invisibility_switch = new Gtk.Switch();
        invisibility_switch.set_halign(Gtk.Align.END);

        bool current_statusdot_invisible = settings?.get_boolean("statusdot-invisible") ?? true;
        invisibility_switch.set_active(current_statusdot_invisible);

        invisibility_switch.notify["active"].connect(() => {
            status_manager.set_invisibility_mode(invisibility_switch.get_active());
        });

        grid.attach(invisibility_label, 0, 0);
        grid.attach(invisibility_switch, 1, 0);
        box.pack_start(grid, true, true, 0);

        var status_toggles_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        build_status_toggles(status_toggles_bar);

        var button_settings = create_icon_button("emblem-system-symbolic", "Settings");

        button_settings.clicked.connect(() => switch_to_settings());

        var hbox_buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        hbox_buttons.add(status_toggles_bar);
        hbox_buttons.add(button_settings);
        box.pack_end(hbox_buttons, false, false, 0);

        return box;
    }

    private Gtk.Box build_settings_view() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

        var grid = new Gtk.Grid();
        grid.set_row_spacing(6);
        grid.set_column_spacing(6);

        string current_base_url = settings?.get_string("statusdot-api-baseurl") ?? "";
        string current_api_key = lookup_api_key() ?? "";
        string current_devicename = settings?.get_string("device-name") ?? "default";
        int current_work_start = settings?.get_int("working-hours-start") ?? 540;
        int current_work_end = settings?.get_int("working-hours-end") ?? 1020;
        bool current_invisible_outside = settings?.get_boolean("invisible-outside-hours") ?? true;
        bool current_away_as_offline = settings?.get_boolean("show-away-as-offline") ?? false;
        bool current_busy_as_offline = settings?.get_boolean("show-busy-as-offline") ?? false;
        int current_away_after_idle = settings?.get_int("away-after-idle") ?? 5;
        int current_offline_after_idle = settings?.get_int("offline-after-idle") ?? 15;

        var label_baseurl_title = new Gtk.Label("Base URL:");
        label_baseurl_title.set_halign(Gtk.Align.END);

        var entry_baseurl = new Gtk.Entry();
        entry_baseurl.set_hexpand(true);
        entry_baseurl.set_halign(Gtk.Align.FILL);
        entry_baseurl.set_text(current_base_url);

        grid.attach(label_baseurl_title, 0, 0, 1, 1);
        grid.attach(entry_baseurl, 1, 0, 1, 1);

        var label_apikey_title = new Gtk.Label("API Key:");
        label_apikey_title.set_halign(Gtk.Align.END);

        var entry_apikey = new Gtk.Entry();
        entry_apikey.set_hexpand(true);
        entry_apikey.set_halign(Gtk.Align.FILL);
        entry_apikey.set_text(current_api_key);
        entry_apikey.visibility = false;

        grid.attach(label_apikey_title, 0, 1, 1, 1);
        grid.attach(entry_apikey, 1, 1, 1, 1);

        var label_devicename_title = new Gtk.Label("Device Name:");
        label_devicename_title.set_halign(Gtk.Align.END);

        var entry_devicename = new Gtk.Entry();
        entry_devicename.set_hexpand(true);
        entry_devicename.set_halign(Gtk.Align.FILL);
        entry_devicename.set_text(current_devicename);

        grid.attach(label_devicename_title, 0, 2, 1, 1);
        grid.attach(entry_devicename, 1, 2, 1, 1);

        var label_work_start = new Gtk.Label("Working hours start:");
        label_work_start.set_halign(Gtk.Align.END);

        var time_work_start_adj = new Gtk.Adjustment(0, 0, 24 * 60 - 1, 30, 60, 0);
        var time_work_start = new Gtk.SpinButton(time_work_start_adj, 30, 0);
        time_work_start.set_hexpand(true);
        time_work_start.set_value(current_work_start);

        time_work_start.output.connect((entry) => {
            int v = entry.get_value_as_int();
            entry.set_text("%02d:%02d".printf(v / 60, v % 60));
            return true;
        });

        time_work_start.input.connect((entry, out new_value) => {
            string[] parts = entry.get_text().split(":");
            if (parts.length == 2) {
                new_value = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                return 1;
            }
            return 0;
        });

        grid.attach(label_work_start, 0, 3, 1, 1);
        grid.attach(time_work_start, 1, 3, 1, 1);

        var label_work_end = new Gtk.Label("Working hours end:");
        label_work_end.set_halign(Gtk.Align.END);

        var time_work_end_adj = new Gtk.Adjustment(0, 0, 24 * 60 - 1, 30, 60, 0);
        var time_work_end = new Gtk.SpinButton(time_work_end_adj, 30, 0);
        time_work_end.set_hexpand(true);
        time_work_end.set_value(current_work_end);

        time_work_end.output.connect((entry) => {
            int v = entry.get_value_as_int();
            entry.set_text("%02d:%02d".printf(v / 60, v % 60));
            return true;
        });

        time_work_end.input.connect((entry, out new_value) => {
            string[] parts = entry.get_text().split(":");
            if (parts.length == 2) {
                new_value = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                return 1;
            }
            return 0;
        });

        grid.attach(label_work_end, 0, 4, 1, 1);
        grid.attach(time_work_end, 1, 4, 1, 1);

        var label_invisible_outside = new Gtk.Label("Invisible outside hours:");
        label_invisible_outside.set_halign(Gtk.Align.END);

        var switch_invisible_outside = new Gtk.Switch();
        switch_invisible_outside.set_halign(Gtk.Align.START);
        switch_invisible_outside.set_active(current_invisible_outside);

        grid.attach(label_invisible_outside, 0, 5, 1, 1);
        grid.attach(switch_invisible_outside, 1, 5, 1, 1);

        var label_away_as_offline = new Gtk.Label("Show away as offline:");
        label_away_as_offline.set_halign(Gtk.Align.END);

        var switch_away_as_offline = new Gtk.Switch();
        switch_away_as_offline.set_halign(Gtk.Align.START);
        switch_away_as_offline.set_active(current_away_as_offline);

        grid.attach(label_away_as_offline, 0, 6, 1, 1);
        grid.attach(switch_away_as_offline, 1, 6, 1, 1);

        var label_busy_as_offline = new Gtk.Label("Show busy as offline:");
        label_busy_as_offline.set_halign(Gtk.Align.END);

        var switch_busy_as_offline = new Gtk.Switch();
        switch_busy_as_offline.set_halign(Gtk.Align.START);
        switch_busy_as_offline.set_active(current_busy_as_offline);

        grid.attach(label_busy_as_offline, 0, 7, 1, 1);
        grid.attach(switch_busy_as_offline, 1, 7, 1, 1);

        var label_away_after_idle = new Gtk.Label("Away after idle (min):");
        label_away_after_idle.set_halign(Gtk.Align.END);
        var spin_away_after_idle = new Gtk.SpinButton.with_range(1, 240, 1);
        spin_away_after_idle.set_hexpand(true);
        spin_away_after_idle.set_value(current_away_after_idle);

        grid.attach(label_away_after_idle, 0, 8, 1, 1);
        grid.attach(spin_away_after_idle, 1, 8, 1, 1);

        var label_offline_after_idle = new Gtk.Label("Offline after idle (min):");
        label_offline_after_idle.set_halign(Gtk.Align.END);
        var spin_offline_after_idle = new Gtk.SpinButton.with_range(1, 480, 1);
        spin_offline_after_idle.set_hexpand(true);
        spin_offline_after_idle.set_value(current_offline_after_idle);

        grid.attach(label_offline_after_idle, 0, 9, 1, 1);
        grid.attach(spin_offline_after_idle, 1, 9, 1, 1);

        box.add(grid);

        var hbox_buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        hbox_buttons.set_halign(Gtk.Align.END);
        var button_back = create_icon_button("go-previous-symbolic", "Back");
        var button_save = create_icon_button("document-save-symbolic", "Save");
        hbox_buttons.add(button_back);
        hbox_buttons.add(button_save);
        box.pack_end(hbox_buttons, false, false, 0);

        button_back.clicked.connect(() => switch_to_main());
        button_save.clicked.connect(() => {
            string new_base_url = entry_baseurl.get_text() ?? "";
            string new_api_key = entry_apikey.get_text() ?? "";
            string new_device_name = entry_devicename.get_text() ?? "";

            store_api_key(new_api_key);

            status_manager.set_device_name(new_device_name);
            status_manager.set_workhours_start(time_work_start.get_value_as_int());
            status_manager.set_workhours_end(time_work_end.get_value_as_int());
            status_manager.set_invisible_outside_hours(switch_invisible_outside.get_active());
            status_manager.set_show_away_as_offline(switch_away_as_offline.get_active());
            status_manager.set_show_busy_as_offline(switch_busy_as_offline.get_active());
            status_manager.set_away_after_idle(spin_away_after_idle.get_value_as_int());
            status_manager.set_offline_after_idle(spin_offline_after_idle.get_value_as_int());

            status_manager.set_api_info(new_base_url, new_api_key);

            switch_to_main();
        });

        return box;
    }

    private void switch_to_main() {
        stack.set_visible_child_name("main");
    }

    private void switch_to_settings() {
        stack.set_visible_child_name("settings");
    }

    private void build_status_toggles(Gtk.Box status_toggles_bar) {
        StatusEnum[] button_values = {
            StatusEnum.ONLINE,
            StatusEnum.AWAY,
            StatusEnum.OFFLINE,
            StatusEnum.BUSY
        };

        string[] tooltips = {
            "Online",
            "Away",
            "Offline",
            "Busy"
        };

        string[] icon_names = {
            "statusdot-online",
            "statusdot-away",
            "statusdot-offline",
            "statusdot-busy",
        };

        foreach (var child in status_toggles_bar.get_children()) {
            status_toggles_bar.remove(child);
        }

        var first_toggle_button = (Gtk.ToggleButton?) null;

        for (int i = 0; i < button_values.length; i++) {
            var status = button_values[i];

            var button_icon = new Gtk.Image.from_icon_name(icon_names[i], Gtk.IconSize.BUTTON);
            var button = new Gtk.ToggleButton();
            button.add(button_icon);
            button.set_tooltip_text(tooltips[i]);
            button.set_hexpand(true);
            button.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);

            button.button_press_event.connect((event) => {
                if (button.get_active()) {
                    return true;
                }

                foreach (var other in status_toggles.get_values()) {
                    if (other != button) {
                        other.set_active(false);
                    }
                }

                button.set_active(true);
                status_manager.set_current_status(status);

                return true;
            });

            status_toggles.insert(status, button);
            status_toggles_bar.pack_start(button, true, true, 0);

            if (first_toggle_button == null) {
                first_toggle_button = button;
            }
        }

        if (first_toggle_button != null) {
            first_toggle_button.set_active(true);
        }
    }

    private Gtk.Box build_warning_box() {
        var css_provider = new Gtk.CssProvider();

        try {
            css_provider.load_from_data(".warning { color: #f27835; }", -1);
        } catch (GLib.Error e) {
            // ignore
        }

        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        box.set_halign(Gtk.Align.FILL);
        box.set_valign(Gtk.Align.START);

        var icon = new Gtk.Image.from_icon_name("dialog-warning-symbolic", Gtk.IconSize.BUTTON);
        icon.get_style_context().add_class("warning");
        box.pack_start(icon, false, false, 0);

        warning_label = new Gtk.Label("");
        warning_label.set_line_wrap(true);
        warning_label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR);
        warning_label.set_xalign(0.0f);
        warning_label.set_halign(Gtk.Align.FILL);
        warning_label.set_valign(Gtk.Align.START);
        warning_label.set_hexpand(true);
        warning_label.get_style_context().add_class("warning");

        var label_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        label_box.set_hexpand(true);
        label_box.set_halign(Gtk.Align.FILL);
        label_box.pack_start(warning_label, true, true, 0);
        box.pack_start(label_box, true, true, 0);

        box.hide();

        return box;
    }

    private void show_warning(string message) {
        warning_label.set_text(message);
        warning_box.show();
    }

    private void hide_warning() {
        warning_box.hide();
    }

    private string? lookup_api_key() {
        try {
            return Secret.password_lookup_sync(
                api_key_schema,
                null,
                "api-key",
                "statusdot",
                null
            );
        } catch (GLib.Error e) {
            warning("Could not read API key: %s", e.message);
            return null;
        }
    }

    private void store_api_key(string token) {
        try {
            Secret.password_store_sync(
                api_key_schema,
                null,
                "Statusdot API key",
                token,
                null,
                "api-key",
                "statusdot",
                null
            );
        } catch (GLib.Error e) {
            show_warning("Could not store API key: %s".printf(e.message));
        }
    }
}