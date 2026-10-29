#include "editor_dialog_fixture.c"
#include <cwhip/Callbacks.h>

static gint64 heartbeat_time;
static gint64 heartbeat_gap;
static guint heartbeat_count;
static guint heartbeat_source;
static guint next_source;
static CwhipCallbackTransfer *next_transfer;

static gboolean explorer_next(gpointer unused) {
    (void)unused;
    int acquired = cwhip_runtime_managed_enter();
    CwhipCallbackContext *context = cwhip_callback_transfer_accept(next_transfer);
    next_source = 0;
    next_transfer = NULL;
    typedef void (*Adapter)(CwhipCallbackContext *);
    ((Adapter)cwhip_callback_adapter(context))(context);
    cwhip_callback_release(context);
    cwhip_callback_dispose(context);
    cwhip_runtime_managed_leave(acquired);
    return G_SOURCE_REMOVE;
}
void explorer_later(void *self, void *callback) {
    (void)self;
    if (next_source) abort();
    next_transfer = cwhip_callback_transfer_prepare(callback, "callback<void()>");
    next_source = g_timeout_add(20, explorer_next, NULL);
}

static gboolean heartbeat(gpointer unused) {
    (void)unused;
    gint64 now = g_get_monotonic_time();
    heartbeat_gap = MAX(heartbeat_gap, now - heartbeat_time);
    heartbeat_time = now;
    ++heartbeat_count;
    return G_SOURCE_CONTINUE;
}
void explorer_watch(void *self) {
    (void)self;
    heartbeat_time = g_get_monotonic_time();
    heartbeat_gap = 0;
    heartbeat_count = 0;
    heartbeat_source = g_timeout_add(10, heartbeat, NULL);
}
int64_t explorer_gap(void *self) {
    (void)self;
    return MAX(heartbeat_gap, g_get_monotonic_time() - heartbeat_time) / 1000;
}
int64_t explorer_beats(void *self) {
    (void)self;
    return heartbeat_count;
}
int64_t explorer_now(void *self) {
    (void)self;
    return g_get_monotonic_time() / 1000;
}
void explorer_stop(void *self) {
    (void)self;
    if (heartbeat_source) g_source_remove(heartbeat_source);
    heartbeat_source = 0;
    if (next_source) {
        g_source_remove(next_source);
        cwhip_callback_transfer_cancel(next_transfer);
        next_source = 0;
        next_transfer = NULL;
    }
    fixture_editor_cleanup(NULL);
}
static GtkWidget *explorer_list(void) {
    GtkWidget *list = find_type(GTK_WIDGET(editor_window()), GTK_TYPE_LIST_VIEW);
    if (!list) abort();
    return list;
}
bool explorer_activate(void *self, int64_t id) {
    (void)self;
    GtkWidget *list = explorer_list();
    GtkSelectionModel *selection = gtk_list_view_get_model(GTK_LIST_VIEW(list));
    guint count = g_list_model_get_n_items(G_LIST_MODEL(selection));
    if (id < 0 || (uint64_t)id >= count) return false;
    g_signal_emit_by_name(list, "activate", (guint)id);
    return true;
}

bool explorer_single_click(void *self) {
    (void)self;
    return gtk_list_view_get_single_click_activate(GTK_LIST_VIEW(explorer_list()));
}

static bool explorer_activate_labeled(GtkWidget *menu, const char *label, bool check_on) {
    GMenuModel *model = gtk_popover_menu_get_menu_model(GTK_POPOVER_MENU(menu));
    GActionMap *actions = g_object_get_data(G_OBJECT(menu), "cwhip-actions");
    if (!model || !actions) return false;
    gint count = g_menu_model_get_n_items(model);
    for (gint i = 0; i < count; ++i) {
        gchar *text = NULL;
        gchar *action_name = NULL;
        g_menu_model_get_item_attribute(model, i, G_MENU_ATTRIBUTE_LABEL, "s", &text);
        g_menu_model_get_item_attribute(model, i, G_MENU_ATTRIBUTE_ACTION, "s", &action_name);
        bool match = text && action_name && strcmp(text, label) == 0 &&
                     g_str_has_prefix(action_name, "menu.");
        if (match) {
            GAction *action = g_action_map_lookup_action(actions, action_name + 5);
            if (!action) match = false;
            else if (check_on) g_action_change_state(action, g_variant_new_boolean(TRUE));
            else g_action_activate(action, NULL);
        }
        g_free(text);
        g_free(action_name);
        if (match) return true;
    }
    return false;
}

bool explorer_context(void *self, bool toggle_hidden) {
    (void)self;
    GtkWidget *list = explorer_list();
    GListModel *controllers = gtk_widget_observe_controllers(list);
    bool opened = false;
    for (guint i = 0; i < g_list_model_get_n_items(controllers); ++i) {
        GtkEventController *controller = g_list_model_get_item(controllers, i);
        if (GTK_IS_GESTURE_CLICK(controller) &&
            gtk_gesture_single_get_button(GTK_GESTURE_SINGLE(controller)) == GDK_BUTTON_SECONDARY) {
            g_signal_emit_by_name(controller, "pressed", 1, 12.0, 12.0);
            opened = true;
        }
        g_object_unref(controller);
    }
    g_object_unref(controllers);
    GtkWidget *menu = find_type(list, GTK_TYPE_POPOVER_MENU);
    if (!menu) menu = find_type(list, GTK_TYPE_POPOVER);
    if (!opened || !menu || !gtk_widget_get_visible(menu) || !GTK_IS_POPOVER_MENU(menu)) return false;
    bool acted = explorer_activate_labeled(menu, toggle_hidden ? "Show Hidden" : "Refresh",
                                           toggle_hidden);
    gtk_popover_popdown(GTK_POPOVER(menu));
    return acted;
}
bool explorer_chooser(void *self) {
    (void)self;
    GListModel *windows = gtk_window_get_toplevels();
    bool found = false;
    for (guint i = 0; i < g_list_model_get_n_items(windows); ++i) {
        GtkWindow *window = g_list_model_get_item(windows, i);
        if (GTK_IS_FILE_CHOOSER(window) && gtk_widget_get_visible(GTK_WIDGET(window))) {
            found = gtk_file_chooser_get_action(GTK_FILE_CHOOSER(window)) ==
                        GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER &&
                    gtk_window_get_transient_for(window) == editor_window() &&
                    gtk_window_get_modal(window);
        }
        g_object_unref(window);
    }
    return found;
}
bool explorer_virtualized(void *self) {
    (void)self;
    GtkWidget *list = explorer_list();
    GtkSelectionModel *selection = gtk_list_view_get_model(GTK_LIST_VIEW(list));
    guint count = g_list_model_get_n_items(G_LIST_MODEL(selection));
    guint widgets = 0;
    for (GtkWidget *child = gtk_widget_get_first_child(list); child;
         child = gtk_widget_get_next_sibling(child))
        ++widgets;
    return count >= 20000 && widgets < 1000;
}
static unsigned explorer_icon_mask(GtkWidget *widget) {
    unsigned mask = 0;
    if (GTK_IS_IMAGE(widget)) {
        const char *name = gtk_image_get_icon_name(GTK_IMAGE(widget));
        if (g_strcmp0(name, "folder-symbolic") == 0) mask |= 1;
        if (g_strcmp0(name, "text-x-generic-symbolic") == 0) mask |= 2;
        if (g_strcmp0(name, "text-x-script-symbolic") == 0) mask |= 4;
        if (g_strcmp0(name, "emblem-symbolic-link-symbolic") == 0) mask |= 8;
    }
    for (GtkWidget *child = gtk_widget_get_first_child(widget); child;
         child = gtk_widget_get_next_sibling(child))
        mask |= explorer_icon_mask(child);
    return mask;
}
bool explorer_icons(void *self) {
    (void)self;
    return explorer_icon_mask(explorer_list()) == 15;
}
