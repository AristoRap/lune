#include <gtk/gtk.h>
#include <string.h>

int open_file_dialog(const char *title, char *out, int out_size) {
    GtkWidget *dialog = gtk_file_chooser_dialog_new(
        title,
        NULL,
        GTK_FILE_CHOOSER_ACTION_OPEN,
        "_Cancel", GTK_RESPONSE_CANCEL,
        "_Open",   GTK_RESPONSE_ACCEPT,
        NULL
    );

    int result = 0;
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        char *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        if (filename) {
            strncpy(out, filename, out_size - 1);
            out[out_size - 1] = '\0';
            g_free(filename);
            result = 1;
        }
    }

    gtk_widget_destroy(dialog);
    while (gtk_events_pending()) gtk_main_iteration();
    return result;
}

int open_dir_dialog(const char *title, char *out, int out_size) {
    GtkWidget *dialog = gtk_file_chooser_dialog_new(
        title, NULL, GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER,
        "_Cancel", GTK_RESPONSE_CANCEL,
        "_Open",   GTK_RESPONSE_ACCEPT,
        NULL
    );

    int result = 0;
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        char *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        if (filename) {
            strncpy(out, filename, out_size - 1);
            out[out_size - 1] = '\0';
            g_free(filename);
            result = 1;
        }
    }
    gtk_widget_destroy(dialog);
    while (gtk_events_pending()) gtk_main_iteration();
    return result;
}

int open_files_dialog(const char *title, char *out, int out_size) {
    GtkWidget *dialog = gtk_file_chooser_dialog_new(
        title, NULL, GTK_FILE_CHOOSER_ACTION_OPEN,
        "_Cancel", GTK_RESPONSE_CANCEL,
        "_Open",   GTK_RESPONSE_ACCEPT,
        NULL
    );
    gtk_file_chooser_set_select_multiple(GTK_FILE_CHOOSER(dialog), TRUE);

    int result = 0;
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        GSList *filenames = gtk_file_chooser_get_filenames(GTK_FILE_CHOOSER(dialog));
        GString *buf = g_string_new(NULL);
        for (GSList *l = filenames; l != NULL; l = l->next) {
            if (buf->len > 0) g_string_append_c(buf, '\n');
            g_string_append(buf, (char *)l->data);
            g_free(l->data);
        }
        g_slist_free(filenames);
        strncpy(out, buf->str, out_size - 1);
        out[out_size - 1] = '\0';
        g_string_free(buf, TRUE);
        result = 1;
    }
    gtk_widget_destroy(dialog);
    while (gtk_events_pending()) gtk_main_iteration();
    return result;
}

// type: 0=info, 1=warning, 2=error, 3=question
int message_dialog(int type, const char *title, const char *message, char *out, int out_size) {
    GtkMessageType msg_type;
    switch (type) {
        case 1: msg_type = GTK_MESSAGE_WARNING; break;
        case 2: msg_type = GTK_MESSAGE_ERROR; break;
        case 3: msg_type = GTK_MESSAGE_QUESTION; break;
        default: msg_type = GTK_MESSAGE_INFO; break;
    }

    GtkButtonsType buttons = (type == 3) ? GTK_BUTTONS_YES_NO : GTK_BUTTONS_OK;
    GtkWidget *dialog = gtk_message_dialog_new(
        NULL, GTK_DIALOG_MODAL, msg_type, buttons, "%s", message
    );
    gtk_window_set_title(GTK_WINDOW(dialog), title);

    gint response = gtk_dialog_run(GTK_DIALOG(dialog));
    gtk_widget_destroy(dialog);
    while (gtk_events_pending()) gtk_main_iteration();

    const char *result = (type == 3 && response == GTK_RESPONSE_YES) ? "Yes" :
                         (type == 3) ? "No" : "Ok";
    strncpy(out, result, out_size - 1);
    out[out_size - 1] = '\0';
    return 1;
}

int save_file_dialog(const char *title, const char *default_name, char *out, int out_size) {
    GtkWidget *dialog = gtk_file_chooser_dialog_new(
        title,
        NULL,
        GTK_FILE_CHOOSER_ACTION_SAVE,
        "_Cancel", GTK_RESPONSE_CANCEL,
        "_Save",   GTK_RESPONSE_ACCEPT,
        NULL
    );

    gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(dialog), TRUE);
    if (default_name && default_name[0]) {
        gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(dialog), default_name);
    }

    int result = 0;
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        char *filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        if (filename) {
            strncpy(out, filename, out_size - 1);
            out[out_size - 1] = '\0';
            g_free(filename);
            result = 1;
        }
    }

    gtk_widget_destroy(dialog);
    while (gtk_events_pending()) gtk_main_iteration();
    return result;
}
