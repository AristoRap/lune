#include <gtk/gtk.h>

void minimize(void *window) {
    gtk_window_iconify(GTK_WINDOW(window));
}

void maximize(void *window) {
    gtk_window_maximize(GTK_WINDOW(window));
}

void set_title(void *window, const char *title) {
    gtk_window_set_title(GTK_WINDOW(window), title);
}

void set_size(void *window, int width, int height) {
    gtk_window_resize(GTK_WINDOW(window), width, height);
}

void center(void *window) {
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
}
