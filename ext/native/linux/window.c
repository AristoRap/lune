#include <gtk/gtk.h>

typedef struct { int x; int y; int width; int height; } WindowFrame;

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

WindowFrame get_frame(void *window) {
    GtkWindow *w = GTK_WINDOW(window);
    WindowFrame f;
    gtk_window_get_position(w, &f.x, &f.y);
    gtk_window_get_size(w, &f.width, &f.height);
    return f;
}

void set_frame(void *window, int x, int y, int width, int height) {
    GtkWindow *w = GTK_WINDOW(window);
    gtk_window_move(w, x, y);
    gtk_window_resize(w, width, height);
}
