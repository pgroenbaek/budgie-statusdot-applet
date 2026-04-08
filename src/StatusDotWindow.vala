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
    //private StatusDotAPI api;
    //private StatusDotManager statusdot_manager;

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

        string base_url = settings?.get_string("statusdot-api-baseurl") ?? "";
        string api_key = lookup_api_key() ?? "";

        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        vbox.set_margin_top(6);
        vbox.set_margin_bottom(6);
        vbox.set_margin_start(6);
        vbox.set_margin_end(6);
        vbox.set_size_request(300, -1);
        add(vbox);

        /*api = new StatusDotAPI(base_url, api_key);
        statusdot_manager = new StatusDotManager(api, c_settings);

        try {
            api.validate_connection();
            hide_warning();
            settings.set_boolean("warning-persistent", false);
        } catch (GLib.Error e) {
            show_warning("%s".printf(e.message));
            settings.set_boolean("warning-persistent", true);
        }*/

        main_view = build_main_view();
        settings_view = build_settings_view();

        stack = new Gtk.Stack();
        stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        stack.set_transition_duration(250);
        stack.add_named(main_view, "main");
        stack.add_named(form_view, "form");
        stack.add_named(settings_view, "settings");
        vbox.add(stack);

        /*statusdot_manager.connected.connect(() => {
            hide_warning();
            settings.set_boolean("warning-persistent", false);
        });
        statusdot_manager.disconnected.connect(() => {
            show_warning("No internet connection");
            settings.set_boolean("warning-persistent", true);
        });
        statusdot_manager.updated.connect(() => {
            update_buttons();
            update_labels();
        });
        statusdot_manager.stopped.connect(() => {
            update_buttons();
            label_duration.set_text("00:00:00");
        });
        statusdot_manager.refresh_from_server();*/

        this.show.connect(() => {
            var warning_persistent = settings.get_boolean("warning-persistent");
            var warning_text = warning_label?.get_text() ?? "";

            if (!warning_persistent || warning_text == null || warning_text == "") {
                hide_warning();
            }
        });
        this.show_all();
    }

    private Gtk.Button create_icon_button(string icon_name, string label_text) {
        var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var image = new Gtk.Image.from_icon_name(icon_name, Gtk.IconSize.BUTTON);

        var label = new Gtk.Label(label_text);
        label.set_halign(Gtk.Align.START);

        hbox.pack_start(image, false, false, 0);
        hbox.pack_start(label, false, false, 0);

        hbox.set_halign(Gtk.Align.CENTER);
        hbox.set_valign(Gtk.Align.CENTER);

        var button = new Gtk.Button();
        button.add(hbox);

        return button;
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

    private Gtk.Box build_main_view() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);


        return box;
    }

    private Gtk.Box build_settings_view() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

        var grid = new Gtk.Grid();
        grid.set_row_spacing(6);
        grid.set_column_spacing(6);

        var label_baseurl_title = new Gtk.Label("Base URL:");
        label_baseurl_title.set_halign(Gtk.Align.END);
        var label_apitoken_title = new Gtk.Label("API Token:");
        label_apitoken_title.set_halign(Gtk.Align.END);

        string current_base_url = settings?.get_string("statusdot-api-baseurl") ?? "";
        string current_api_key = lookup_api_key() ?? "";

        var entry_baseurl = new Gtk.Entry();
        entry_baseurl.set_hexpand(true);
        entry_baseurl.set_halign(Gtk.Align.FILL);
        entry_baseurl.set_text(current_base_url);

        var entry_apitoken = new Gtk.Entry();
        entry_apitoken.set_hexpand(true);
        entry_apitoken.set_halign(Gtk.Align.FILL);
        entry_apitoken.set_text(current_api_key);
        entry_apitoken.visibility = false;

        grid.attach(label_baseurl_title, 0, 0, 1, 1);
        grid.attach(entry_baseurl, 1, 0, 1, 1);
        grid.attach(label_apitoken_title, 0, 1, 1, 1);
        grid.attach(entry_apitoken, 1, 1, 1, 1);
        box.add(grid);

        var hbox_buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var button_back = create_icon_button("go-previous-symbolic", "Back");
        var button_save = create_icon_button("document-save-symbolic", "Save");
        hbox_buttons.add(button_back);
        hbox_buttons.add(button_save);
        box.pack_end(hbox_buttons, false, false, 0);

        button_back.clicked.connect(() => switch_to_main());
        button_save.clicked.connect(() => {
            string new_base_url = entry_baseurl.get_text() ?? "";
            string new_api_key = entry_apitoken.get_text() ?? "";

            settings?.set_string("statusdot-api-baseurl", new_base_url);
            store_api_key(new_api_key);

            /*api = new StatusDotAPI(new_base_url, new_api_key);

            try {
                api.validate_connection();
                hide_warning();
                refresh_combobox_data();
                settings.set_boolean("warning-persistent", false);
            } catch (GLib.Error e) {
                show_warning("%s".printf(e.message));
                settings.set_boolean("warning-persistent", true);
            }

            statusdot_manager.set_api(api);
            statusdot_manager.refresh_from_server();*/

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

    private void refresh_combobox_data() {
        /*api.get_customers.begin((obj, res) => {
            try {
                var customers = api.get_customers.end(res);
                foreach (var customer in customers) {
                    combobox_customer.append(customer.id.to_string(), customer.name);
                }
            } catch (GLib.Error e) {
                show_warning("Could not fetch customers: %s".printf(e.message));
            }
        });*/
    }

    private void update_labels() {
        label_customer.set_text(statusdot_manager.customer);
        label_project.set_text(statusdot_manager.project);
        label_activity.set_text(statusdot_manager.activity);
        label_description.set_text(statusdot_manager.description);

        int hours = statusdot_manager.elapsed_seconds / 3600;
        int minutes = (statusdot_manager.elapsed_seconds % 3600) / 60;
        int seconds = statusdot_manager.elapsed_seconds % 60;

        label_duration.set_text("%02d:%02d:%02d".printf(hours, minutes, seconds));
    }

    private void update_buttons() {
        var is_running = settings.get_boolean("timetracker-running");

        if (is_running) {
            button_start.set_sensitive(false);
            button_stop.set_sensitive(true);
            button_new.set_sensitive(false);
        }
        else {
            var show_start = has_last_timesheet() ? true : false;
            button_start.set_sensitive(show_start);
            button_stop.set_sensitive(false);
            button_new.set_sensitive(true);
        }
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
                "Statusdot API token",
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