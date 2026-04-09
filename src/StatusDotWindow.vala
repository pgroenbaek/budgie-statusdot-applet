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
    private Gtk.ComboBox? status_combobox = null;
    private Gtk.ListStore? status_store = null;
    private Gtk.Label? status_label = null;

    private ulong invisibility_id;

    private unowned GLib.Settings? settings;

    public StatusDotWindow(Gtk.Widget? c_parent, GLib.Settings? c_settings) {
        Object(relative_to: c_parent);
        settings = c_settings;
        get_style_context().add_class("statusdot-popover");

        var container = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        container.get_style_context().add_class("container");

        var css = new Gtk.CssProvider();

        try {
            css.load_from_data("label.bold-grey { font-weight: bold; color: #8d939e; }");
        } catch (GLib.Error e) {
            // ignore
        }

        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        /*
        Top box with title and enabled switch.
        */
        var top_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        top_box.set_hexpand(true);

        var title_label = new Gtk.Label("Status Dot");
        title_label.get_style_context().add_class("bold-grey");
        title_label.set_halign(Gtk.Align.START);
        title_label.set_hexpand(true);
        top_box.pack_start(title_label, true, true, 0);

        invisibility_switch = new Gtk.Switch();
        invisibility_switch.set_halign(Gtk.Align.END);
        invisibility_switch.set_margin_start(6);
        top_box.set_margin_start(3);
        top_box.set_margin_end(3);
        top_box.pack_start(invisibility_switch, false, false, 0);

        var top_seperator = new Gtk.Separator(Orientation.HORIZONTAL);
        top_seperator.set_margin_top(2);
        top_seperator.set_margin_bottom(2);

        top_box.set_size_request(-1, 30);
        container.pack_start(top_box, true, true, 0);
        container.pack_start(top_seperator, false, false, 0);

        /*
        Top grid with device selection.
        */
        var top_grid = new Gtk.Grid();
        top_grid.set_row_spacing(6);
        top_grid.set_column_spacing(12);

        status_label = new Gtk.Label(_("Status"));
        status_label.set_halign(Gtk.Align.START);

        var status_renderer = new Gtk.CellRendererText();
        status_store = new Gtk.ListStore(2, typeof(string), typeof(string));
        status_combobox = new Gtk.ComboBox();
        status_combobox.set_model(status_store);
        status_combobox.set_id_column(0);
        status_combobox.pack_start(status_renderer, true);
        status_combobox.add_attribute(status_renderer, "text", 1);
        status_combobox.set_halign(Gtk.Align.END);
        status_combobox.set_hexpand(true);
        status_combobox.set_size_request(90, -1);

        Gtk.TreeIter iter;
        status_store.append(out iter);
        status_store.set(iter,
            0, "%d".printf(StatusEnum.OFFLINE),
            1, "Offline"
        );
        status_store.append(out iter);
        status_store.set(iter,
            0, "%d".printf(StatusEnum.ONLINE),
            1, "Online"
        );
        status_store.append(out iter);
        status_store.set(iter,
            0, "%d".printf(StatusEnum.AWAY),
            1, "Away"
        );
        status_store.append(out iter);
        status_store.set(iter,
            0, "%d".printf(StatusEnum.BUSY),
            1, "Busy"
        );

        top_grid.attach(status_label, 0, 0);
        top_grid.attach(status_combobox, 1, 0);

        container.pack_start(top_grid, true, true, 0);
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

        status_combobox.changed.connect(() => {
            print("combobox changed → %s\n", status_combobox.get_active_id());
            StatusEnum status = get_status();

            int old_value = settings.get_int("statusdot-state");
            int new_value = (int) status;
            print("GSettings change: old=%d, new=%d\n", old_value, new_value);

            settings.set_int("statusdot-state", (int) status);
        });

        invisibility_id = invisibility_switch.notify["active"].connect(() => {
            SignalHandler.block(invisibility_switch, invisibility_id);
            bool invisible = !invisibility_switch.get_active();
            settings.set_boolean("statusdot-invisible", invisible);
            set_invisibility(invisible);
            SignalHandler.unblock(invisibility_switch, invisibility_id);
        });

        this.show_all();
    }

    private void set_status(StatusEnum status) {
        status_combobox.set_active_id("%d".printf(status));
    }

    private StatusEnum get_status() {
        string? id = status_combobox.get_active_id();

        if (id != null) {
            return (StatusEnum) int.parse(id);
        }

        return StatusEnum.OFFLINE;
    }

    private void set_invisibility(bool invisible) {
        bool visible = !invisible;

        if (invisibility_switch.get_active() != visible) {
            invisibility_switch.set_active(visible);
        }

        status_combobox.set_sensitive(visible);
        status_label.set_sensitive(visible);
    }

    /*private Gtk.Button create_icon_button(string icon_name, string label_text) {
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

            api = new StatusDotAPI(new_base_url, new_api_key);

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
            statusdot_manager.refresh_from_server();

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
        api.get_customers.begin((obj, res) => {
            try {
                var customers = api.get_customers.end(res);
                foreach (var customer in customers) {
                    combobox_customer.append(customer.id.to_string(), customer.name);
                }
            } catch (GLib.Error e) {
                show_warning("Could not fetch customers: %s".printf(e.message));
            }
        });
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
    }*/
}