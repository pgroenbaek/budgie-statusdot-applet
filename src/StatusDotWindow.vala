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

/*
TODO Settings:
    - api key
	- api baseurl
	- working hours
	- never show online outside working hours checkbox
	- show away as offline checkbox
	- away after x minutes idle
	- away duration before going offline (x minutes)
TODO UI:
    - Togglebutton status change
*/

public class StatusDotWindow : Budgie.Popover {

    private Gtk.Switch? invisibility_switch = null;

    private Gtk.Stack? stack = null;
    private Gtk.Box? main_view = null;
    private Gtk.Box? settings_view = null;

    private Gtk.Label warning_label;
    private Gtk.Box warning_box;

    private GLib.List<Gtk.ToggleButton> status_toggles = new GLib.List<Gtk.ToggleButton>();

    private ulong invisibility_id;

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
        Initial state.
        */
        set_status(StatusEnum.OFFLINE);
        set_invisibility(true);

        /*
        Events wiring.
        */
        settings.changed["statusdot-state"].connect(() => {
            int value = settings.get_int("statusdot-state");
            StatusEnum status = (StatusEnum) value;

            set_status(status);
        });

        settings.changed["statusdot-invisible"].connect(() => {
            bool invisible = settings.get_boolean("statusdot-invisible");

            set_invisibility(invisible);
        });
        
        this.show.connect(() => {
            var warning_persistent = settings.get_boolean("warning-persistent");
            var warning_text = warning_label?.get_text() ?? "";

            if (!warning_persistent || warning_text == null || warning_text == "") {
                hide_warning();
            }
        });
        this.show_all();
    }

    private void set_status(StatusEnum status) {
        
    }

    private void set_invisibility(bool invisible) {
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

        grid.attach(invisibility_label, 0, 0);
        grid.attach(invisibility_switch, 1, 0);
        box.pack_start(grid, true, true, 0);

        var status_toggles_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        status_toggles = build_status_toggles(status_toggles_bar);

        var button_settings = create_icon_button("emblem-system-symbolic", "Settings");

        var hbox_buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        hbox_buttons.add(status_toggles_bar);
        hbox_buttons.add(button_settings);
        box.pack_end(hbox_buttons, false, false, 0);

        invisibility_id = invisibility_switch.notify["active"].connect(() => {
            SignalHandler.block(invisibility_switch, invisibility_id);
            bool invisible = invisibility_switch.get_active();
            settings.set_boolean("statusdot-invisible", invisible);
            set_invisibility(invisible);
            SignalHandler.unblock(invisibility_switch, invisibility_id);
        });

        button_settings.clicked.connect(() => switch_to_settings());

        return box;
    }

    private Gtk.Box build_settings_view() {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

        var grid = new Gtk.Grid();
        grid.set_row_spacing(6);
        grid.set_column_spacing(6);

        var label_baseurl_title = new Gtk.Label("Base URL:");
        label_baseurl_title.set_halign(Gtk.Align.END);
        var label_apikey_title = new Gtk.Label("API Key:");
        label_apikey_title.set_halign(Gtk.Align.END);

        string current_base_url = settings?.get_string("statusdot-api-baseurl") ?? "";
        //string current_api_token = lookup_api_token() ?? "";

        var entry_baseurl = new Gtk.Entry();
        entry_baseurl.set_hexpand(true);
        entry_baseurl.set_halign(Gtk.Align.FILL);
        entry_baseurl.set_text(current_base_url);

        var entry_apikey = new Gtk.Entry();
        entry_apikey.set_hexpand(true);
        entry_apikey.set_halign(Gtk.Align.FILL);
        //entry_apikey.set_text(current_api_token);
        entry_apikey.visibility = false;

        grid.attach(label_baseurl_title, 0, 0, 1, 1);
        grid.attach(entry_baseurl, 1, 0, 1, 1);
        grid.attach(label_apikey_title, 0, 1, 1, 1);
        grid.attach(entry_apikey, 1, 1, 1, 1);
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
            /*string new_base_url = entry_baseurl.get_text() ?? "";
            string new_api_token = entry_apitoken.get_text() ?? "";

            settings?.set_string("kimai-api-baseurl", new_base_url);
            store_api_token(new_api_token);

            api = new KimaiAPI(new_base_url, new_api_token);

            try {
                api.validate_connection();
                hide_warning();
                refresh_combobox_data();
                settings.set_boolean("warning-persistent", false);
            } catch (GLib.Error e) {
                show_warning("%s".printf(e.message));
                settings.set_boolean("warning-persistent", true);
            }

            timer_manager.set_api(api);
            timer_manager.refresh_from_server();*/

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

    private GLib.List<Gtk.ToggleButton> build_status_toggles(Gtk.Box status_toggles_bar) {
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
            "statusdot-active-online",
            "statusdot-active-away",
            "statusdot-active-offline",
            "statusdot-active-busy",
        };

        foreach (var child in status_toggles_bar.get_children()) {
            status_toggles_bar.remove(child);
        }

        var first_toggle_button = (Gtk.ToggleButton?) null;
        var toggle_buttons = new GLib.List<Gtk.ToggleButton>();

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

                foreach (var other in status_toggles) {
                    if (other != button) {
                        other.set_active(false);
                    }
                }

                button.set_active(true);
                settings.set_int("statusdot-state", (int) status);

                return true;
            });

            toggle_buttons.append(button);
            status_toggles_bar.pack_start(button, true, true, 0);

            if (first_toggle_button == null) {
                first_toggle_button = button;
            }
        }

        if (first_toggle_button != null) {
            first_toggle_button.set_active(true);
        }

        return toggle_buttons;
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