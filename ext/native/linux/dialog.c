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
