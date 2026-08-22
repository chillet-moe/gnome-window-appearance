#define _GNU_SOURCE

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>

#include "xdg-shell-client-protocol.h"

enum
{
  FRAME_X = 26,
  FRAME_Y = 23,
  FRAME_WIDTH = 760,
  FRAME_HEIGHT = 457,
  BUFFER_WIDTH = 812,
  BUFFER_HEIGHT = 509,
  SUBSURFACE_SIZE = 64,
};

static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct wl_subcompositor *subcompositor;
static struct xdg_wm_base *wm_base;
static struct wl_surface *surface;
static struct wl_surface *child_surface;
static struct wl_subsurface *subsurface;
static struct xdg_surface *xdg_surface;
static struct xdg_toplevel *toplevel;
static int pending_width;
static int pending_height;
static int pending_maximized;
static int pending_fullscreen;

static struct wl_buffer *
create_buffer (int       width,
               int       height,
               uint32_t *pixels)
{
  const int stride = width * 4;
  const int size = stride * height;
  int fd = memfd_create ("gnome-window-appearance-probe", 0);
  void *mapping;
  struct wl_shm_pool *pool;
  struct wl_buffer *buffer;

  if (fd < 0 || ftruncate (fd, size) < 0)
    abort ();

  mapping = mmap (NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if (mapping == MAP_FAILED)
    abort ();
  memcpy (mapping, pixels, size);
  munmap (mapping, size);

  pool = wl_shm_create_pool (shm, fd, size);
  buffer = wl_shm_pool_create_buffer (pool, 0, width, height, stride,
                                      WL_SHM_FORMAT_ARGB8888);
  wl_shm_pool_destroy (pool);
  close (fd);

  return buffer;
}

static void
draw_surfaces (void)
{
  int frame_x = FRAME_X;
  int frame_y = FRAME_Y;
  int frame_width = pending_width > 0 ? pending_width : FRAME_WIDTH;
  int frame_height = pending_height > 0 ? pending_height : FRAME_HEIGHT;
  int buffer_width;
  int buffer_height;
  struct wl_buffer *parent_buffer;
  struct wl_buffer *child_buffer;
  uint32_t *parent_pixels;
  uint32_t child_pixels[SUBSURFACE_SIZE * SUBSURFACE_SIZE];

  if (pending_maximized || pending_fullscreen)
    frame_x = frame_y = 0;

  buffer_width = frame_width + (frame_x == 0 ? 0 : BUFFER_WIDTH - FRAME_WIDTH);
  buffer_height = frame_height + (frame_y == 0 ? 0 : BUFFER_HEIGHT - FRAME_HEIGHT);

  parent_pixels = calloc (buffer_width * buffer_height, sizeof (uint32_t));
  if (!parent_pixels)
    abort ();
  for (int y = frame_y; y < frame_y + frame_height; y++)
    for (int x = frame_x; x < frame_x + frame_width; x++)
      parent_pixels[y * buffer_width + x] = 0xfff5f5f5;
  for (int y = frame_y; y < frame_y + SUBSURFACE_SIZE; y++)
    for (int x = frame_x; x < frame_x + SUBSURFACE_SIZE; x++)
      parent_pixels[y * buffer_width + x] = 0;
  parent_buffer = create_buffer (buffer_width, buffer_height, parent_pixels);
  free (parent_pixels);

  for (size_t i = 0; i < sizeof (child_pixels) / sizeof (child_pixels[0]); i++)
    child_pixels[i] = 0xffff0000;
  child_buffer = create_buffer (SUBSURFACE_SIZE, SUBSURFACE_SIZE, child_pixels);

  wl_subsurface_set_position (subsurface, frame_x, frame_y);
  wl_surface_attach (child_surface, child_buffer, 0, 0);
  wl_surface_damage_buffer (child_surface, 0, 0,
                            SUBSURFACE_SIZE, SUBSURFACE_SIZE);
  wl_surface_commit (child_surface);

  wl_surface_attach (surface, parent_buffer, 0, 0);
  xdg_surface_set_window_geometry (xdg_surface,
                                   frame_x, frame_y,
                                   frame_width, frame_height);
  wl_surface_damage_buffer (surface, 0, 0, buffer_width, buffer_height);
  wl_surface_commit (surface);
}

static void
wm_base_ping (void              *data,
              struct xdg_wm_base *base,
              uint32_t           serial)
{
  xdg_wm_base_pong (base, serial);
}

static const struct xdg_wm_base_listener wm_base_listener = {
  .ping = wm_base_ping,
};

static void
registry_global (void               *data,
                 struct wl_registry *registry,
                 uint32_t            name,
                 const char         *interface,
                 uint32_t            version)
{
  if (strcmp (interface, wl_compositor_interface.name) == 0)
    compositor = wl_registry_bind (registry, name,
                                   &wl_compositor_interface, 4);
  else if (strcmp (interface, wl_shm_interface.name) == 0)
    shm = wl_registry_bind (registry, name, &wl_shm_interface, 1);
  else if (strcmp (interface, wl_subcompositor_interface.name) == 0)
    subcompositor = wl_registry_bind (registry, name,
                                      &wl_subcompositor_interface, 1);
  else if (strcmp (interface, xdg_wm_base_interface.name) == 0)
    {
      wm_base = wl_registry_bind (registry, name, &xdg_wm_base_interface,
                                  version < 6 ? version : 6);
      xdg_wm_base_add_listener (wm_base, &wm_base_listener, NULL);
    }
}

static void
registry_global_remove (void               *data,
                        struct wl_registry *registry,
                        uint32_t            name)
{
}

static const struct wl_registry_listener registry_listener = {
  .global = registry_global,
  .global_remove = registry_global_remove,
};

static void
xdg_surface_configure (void               *data,
                       struct xdg_surface *configured_surface,
                       uint32_t            serial)
{
  xdg_surface_ack_configure (configured_surface, serial);
  draw_surfaces ();
}

static const struct xdg_surface_listener xdg_surface_listener = {
  .configure = xdg_surface_configure,
};

static void
toplevel_configure (void                *data,
                    struct xdg_toplevel *configured_toplevel,
                    int32_t              width,
                    int32_t              height,
                    struct wl_array     *states)
{
  uint32_t *state;

  pending_width = width;
  pending_height = height;
  pending_maximized = 0;
  pending_fullscreen = 0;
  wl_array_for_each (state, states)
    {
      if (*state == XDG_TOPLEVEL_STATE_MAXIMIZED)
        pending_maximized = 1;
      else if (*state == XDG_TOPLEVEL_STATE_FULLSCREEN)
        pending_fullscreen = 1;
    }
}

static void
toplevel_close (void                *data,
                struct xdg_toplevel *closed_toplevel)
{
  exit (0);
}

static void
toplevel_configure_bounds (void                *data,
                           struct xdg_toplevel *configured_toplevel,
                           int32_t              width,
                           int32_t              height)
{
}

static void
toplevel_wm_capabilities (void                *data,
                          struct xdg_toplevel *configured_toplevel,
                          struct wl_array     *capabilities)
{
}

static const struct xdg_toplevel_listener toplevel_listener = {
  .configure = toplevel_configure,
  .close = toplevel_close,
  .configure_bounds = toplevel_configure_bounds,
  .wm_capabilities = toplevel_wm_capabilities,
};

int
main (void)
{
  struct wl_display *display = wl_display_connect (NULL);
  struct wl_registry *registry;

  if (!display)
    return 1;

  registry = wl_display_get_registry (display);
  wl_registry_add_listener (registry, &registry_listener, NULL);
  wl_display_roundtrip (display);
  if (!compositor || !shm || !subcompositor || !wm_base)
    return 2;

  surface = wl_compositor_create_surface (compositor);
  xdg_surface = xdg_wm_base_get_xdg_surface (wm_base, surface);
  xdg_surface_add_listener (xdg_surface, &xdg_surface_listener, NULL);
  toplevel = xdg_surface_get_toplevel (xdg_surface);
  xdg_toplevel_add_listener (toplevel, &toplevel_listener, NULL);
  xdg_toplevel_set_title (toplevel, "Window Appearance Subsurface Probe");
  xdg_toplevel_set_app_id (toplevel, "subsurface-probe");

  child_surface = wl_compositor_create_surface (compositor);
  subsurface = wl_subcompositor_get_subsurface (subcompositor,
                                                child_surface, surface);
  wl_surface_commit (surface);

  while (wl_display_dispatch (display) >= 0)
    ;

  return 0;
}
