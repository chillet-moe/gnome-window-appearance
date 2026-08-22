#include <gtk/gtk.h>

static gboolean draw_probe(GtkWidget *widget, cairo_t *cr, gpointer data)
{
    (void) data;
    GtkAllocation allocation;
    gtk_widget_get_allocation(widget, &allocation);

    cairo_set_source_rgb(cr, 0.96, 0.96, 0.96);
    cairo_paint(cr);

    cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE);
    for (int x = 24; x < allocation.width - 24; x += 2) {
        cairo_set_source_rgb(cr, (x / 2) % 2, (x / 2) % 2, (x / 2) % 2);
        cairo_rectangle(cr, x, 72, 1, 120);
        cairo_fill(cr);
    }

    for (int y = 212; y < 292; y += 2) {
        cairo_set_source_rgb(cr, (y / 2) % 2, 0.2, 1.0 - (y / 2) % 2);
        cairo_rectangle(cr, 24, y, allocation.width - 48, 1);
        cairo_fill(cr);
    }

    cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT);
    cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL,
                           CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, 22);
    cairo_set_source_rgb(cr, 0.05, 0.05, 0.05);
    cairo_move_to(cr, 24, 45);
    cairo_show_text(cr, "GNOME fractional-scale clarity probe 1px | Il1");

    return GDK_EVENT_PROPAGATE;
}

int main(int argc, char **argv)
{
    gtk_init(&argc, &argv);

    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "Window Appearance Probe");
    gtk_window_set_default_size(GTK_WINDOW(window), 760, 420);
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    GtkWidget *drawing_area = gtk_drawing_area_new();
    g_signal_connect(drawing_area, "draw", G_CALLBACK(draw_probe), NULL);
    gtk_container_add(GTK_CONTAINER(window), drawing_area);
    gtk_widget_show_all(window);

    gtk_main();
    return 0;
}
