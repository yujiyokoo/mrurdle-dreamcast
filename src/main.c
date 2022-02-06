#include <kos.h>
#include <mruby.h>
#include <mruby/irep.h>
#include "mrubydle.h"

/* These macros tell KOS how to initialize itself. All of this initialization
   happens before main() gets called, and the shutdown happens afterwards. So
   you need to set any flags you want here. Here are some possibilities:

   INIT_NONE        -- don't do any auto init
   INIT_IRQ     -- Enable IRQs
   INIT_THD_PREEMPT -- Enable pre-emptive threading
   INIT_NET     -- Enable networking (doesn't imply lwIP!)
   INIT_MALLOCSTATS -- Enable a call to malloc_stats() right before shutdown

   You can OR any or all of those together. If you want to start out with
   the current KOS defaults, use INIT_DEFAULT (or leave it out entirely). */
KOS_INIT_FLAGS(INIT_DEFAULT | INIT_MALLOCSTATS);

/* You can safely remove this line if you don't use a ROMDISK */
extern uint8 romdisk[];
/* And specify a romdisk, if you want one (or leave it out) */
KOS_INIT_ROMDISK(romdisk);

extern const uint8_t game[]; // declared in the rb file

int main(int argc, char **argv) {
  vid_set_mode(DM_640x480_VGA, PM_RGB565);

  mrb_state *mrb = mrb_open();
  if (!mrb) { return 1; }

  struct RClass *dc2d_module = mrb_define_module(mrb, "Dc2d");

  define_module_functions(mrb, dc2d_module);

  mrb_load_irep(mrb, game);

  print_exception(mrb);

  mrb_close(mrb);

  return 0;
}
