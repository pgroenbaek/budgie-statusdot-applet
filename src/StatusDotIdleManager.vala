using GLib;

[CCode (cheader_filename = "X11/Xlib.h")]
public extern void* XOpenDisplay (string? name);

[CCode (cheader_filename = "X11/Xlib.h")]
public extern ulong XDefaultRootWindow (void* display);

[CCode (cname = "XScreenSaverAllocInfo")]
public extern void* xss_alloc ();

[CCode (cname = "XScreenSaverQueryInfo")]
public extern int xss_query (
    void* display,
    ulong drawable,
    void* info
);

public class StatusDotIdleManager : Object {

    public uint64 get_idle_seconds() {

        void* display = XOpenDisplay (null);
        if (display == null)
            return 0;

        ulong root = XDefaultRootWindow(display);

        void* info = xss_alloc();
        if (info == null)
            return 0;

        xss_query (display, root, info);

        uint64 idle = ((uint64[]) info)[3];

        return idle / 1000;
    }

    public string get_backend_name () {
        return "x11-xss";
    }
}