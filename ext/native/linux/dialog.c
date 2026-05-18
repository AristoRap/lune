#include <gtk/gtk.h>
#include <pthread.h>
#include <string.h>

// gtk_dialog_run() and all GTK widget calls require the main thread.
// Binding callbacks may arrive on any Crystal fiber thread, so we dispatch
// synchronously to the GTK main loop when needed.

static pthread_t       _main_tid;
static pthread_once_t  _once = PTHREAD_ONCE_INIT;
static void _capture(void) { _main_tid = pthread_self(); }

typedef struct { void (*fn)(void *); void *d; GMutex m; GCond c; gboolean done; } _Call;

static gboolean _call_cb(gpointer p) {
    _Call *c = p;
    c->fn(c->d);
    g_mutex_lock(&c->m);
    c->done = TRUE;
    g_cond_signal(&c->c);
    g_mutex_unlock(&c->m);
    return G_SOURCE_REMOVE;
}

static void run_on_main(void (*fn)(void *), void *d) {
    pthread_once(&_once, _capture);
    if (pthread_equal(pthread_self(), _main_tid)) { fn(d); return; }
    _Call c = {.fn = fn, .d = d, .done = FALSE};
    g_mutex_init(&c.m); g_cond_init(&c.c);
    g_idle_add(_call_cb, &c);
    g_mutex_lock(&c.m);
    while (!c.done) g_cond_wait(&c.c, &c.m);
    g_mutex_unlock(&c.m);
    g_mutex_clear(&c.m); g_cond_clear(&c.c);
}

// ── Dialog implementations ────────────────────────────────────────────────────

typedef struct { const char *title; char *out; int out_size; int result; } OpenArgs;
typedef struct { int type; const char *title; const char *msg; char *out; int out_size; int result; } MsgArgs;
typedef struct { const char *title; const char *default_name; char *out; int out_size; int result; } SaveArgs;

static void _open_file_impl(void *p) {
    OpenArgs *a = p;
    GtkWidget *dialog = gtk_file_chooser_dialog_new(
        a->title, NULL, GTK_FILE_CHOOSER_ACTION_OPEN,
        "_Cancel", GTK_RESPONSE_CANCEL, "_Open", GTK_RESPONSE_ACCEPT, NULL);
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        char *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        if (filename) {
            strncpy(a->out, filename, a->out_size - 1);
            a->out[a->out_size - 1] = '\0';
            g_free(filename);
            a->result = 1;
        }
    }
    gtk_widget_destroy(dialog);
    while (gtk_events_pending()) gtk_main_iteration();
}

static void _open_dir_impl(void *p) {
    OpenArgs *a = p;
    GtkWidget *dialog = gtk_file_chooser_dialog_new(
        a->title, NULL, GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER,
        "_Cancel", GTK_RESPONSE_CANCEL, "_Open", GTK_RESPONSE_ACCEPT, NULL);
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        char *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        if (filename) {
            strncpy(a->out, filename, a->out_size - 1);
            a->out[a->out_size - 1] = '\0';
            g_free(filename);
            a->result = 1;
        }
    }
    gtk_widget_destroy(dialog);
    while (gtk_events_pending()) gtk_main_iteration();
}

static void _open_files_impl(void *p) {
    OpenArgs *a = p;
    GtkWidget *dialog = gtk_file_chooser_dialog_new(
        a->title, NULL, GTK_FILE_CHOOSER_ACTION_OPEN,
        "_Cancel", GTK_RESPONSE_CANCEL, "_Open", GTK_RESPONSE_ACCEPT, NULL);
    gtk_file_chooser_set_select_multiple(GTK_FILE_CHOOSER(dialog), TRUE);
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        GSList *filenames = gtk_file_chooser_get_filenames(GTK_FILE_CHOOSER(dialog));
        GString *buf = g_string_new(NULL);
        for (GSList *l = filenames; l != NULL; l = l->next) {
            if (buf->len > 0) g_string_append_c(buf, '\n');
            g_string_append(buf, (char *)l->data);
            g_free(l->data);
        }
        g_slist_free(filenames);
        strncpy(a->out, buf->str, a->out_size - 1);
        a->out[a->out_size - 1] = '\0';
        g_string_free(buf, TRUE);
        a->result = 1;
    }
    gtk_widget_destroy(dialog);
    while (gtk_events_pending()) gtk_main_iteration();
}

static void _message_impl(void *p) {
    MsgArgs *a = p;
    GtkMessageType msg_type;
    switch (a->type) {
        case 1: msg_type = GTK_MESSAGE_WARNING;  break;
        case 2: msg_type = GTK_MESSAGE_ERROR;    break;
        case 3: msg_type = GTK_MESSAGE_QUESTION; break;
        default: msg_type = GTK_MESSAGE_INFO;    break;
    }
    GtkButtonsType buttons = (a->type == 3) ? GTK_BUTTONS_YES_NO : GTK_BUTTONS_OK;
    GtkWidget *dialog = gtk_message_dialog_new(
        NULL, GTK_DIALOG_MODAL, msg_type, buttons, "%s", a->msg);
    gtk_window_set_title(GTK_WINDOW(dialog), a->title);
    gint response = gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
    while (gtk_events_pending()) gtk_main_iteration();
    const char *result = (a->type == 3 && response == GTK_RESPONSE_YES) ? "Yes" :
                         (a->type == 3) ? "No" : "Ok";
    strncpy(a->out, result, a->out_size - 1);
    a->out[a->out_size - 1] = '\0';
    a->result = 1;
}

static void _save_file_impl(void *p) {
    SaveArgs *a = p;
    GtkWidget *dialog = gtk_file_chooser_dialog_new(
        a->title, NULL, GTK_FILE_CHOOSER_ACTION_SAVE,
        "_Cancel", GTK_RESPONSE_CANCEL, "_Save", GTK_RESPONSE_ACCEPT, NULL);
    gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(dialog), TRUE);
    if (a->default_name && a->default_name[0])
        gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(dialog), a->default_name);
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        char *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        if (filename) {
            strncpy(a->out, filename, a->out_size - 1);
            a->out[a->out_size - 1] = '\0';
            g_free(filename);
            a->result = 1;
        }
    }
    gtk_widget_destroy(dialog);
    while (gtk_events_pending()) gtk_main_iteration();
}

// ── Public API ────────────────────────────────────────────────────────────────

int open_file_dialog(const char *title, char *out, int out_size) {
    OpenArgs a = {title, out, out_size, 0};
    run_on_main(_open_file_impl, &a);
    return a.result;
}

int open_dir_dialog(const char *title, char *out, int out_size) {
    OpenArgs a = {title, out, out_size, 0};
    run_on_main(_open_dir_impl, &a);
    return a.result;
}

int open_files_dialog(const char *title, char *out, int out_size) {
    OpenArgs a = {title, out, out_size, 0};
    run_on_main(_open_files_impl, &a);
    return a.result;
}

// type: 0=info, 1=warning, 2=error, 3=question
int message_dialog(int type, const char *title, const char *message, char *out, int out_size) {
    MsgArgs a = {type, title, message, out, out_size, 0};
    run_on_main(_message_impl, &a);
    return a.result;
}

int save_file_dialog(const char *title, const char *default_name, char *out, int out_size) {
    SaveArgs a = {title, default_name, out, out_size, 0};
    run_on_main(_save_file_impl, &a);
    return a.result;
}
