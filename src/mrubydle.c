#include <kos.h>
#include <mruby.h>
// #include <mruby/data.h>
#include <mruby/string.h>
#include <mruby/error.h>
#include <mruby/array.h>
// #include <stdio.h>
// #include <inttypes.h>

#define PACK_PIXEL(r, g, b) ( ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)  )

#define BUFSIZE 100

struct InputBuf {
  uint16_t buffer[BUFSIZE];
  uint32_t index;
} input_buf;


static mrb_value btn_mrb_buffer;

// buf has to be BUFSIZE elements at least
void *read_buttons() {
  while(1) {
    input_buf.index = (input_buf.index + 1) % BUFSIZE;
    maple_device_t *cont1;
    cont_state_t *state;
    if((cont1 = maple_enum_type(0, MAPLE_FUNC_CONTROLLER))){
      state = (cont_state_t *)maple_dev_status(cont1);
      input_buf.buffer[input_buf.index] = state->buttons;
    }

    thd_pass();
  }
}

static mrb_value init_controller_buffer(mrb_state *mrb, mrb_value self) {
  btn_mrb_buffer = mrb_ary_new(mrb);;
  input_buf.index = 0;

  int i = 0;
  while(i < BUFSIZE) {
    mrb_ary_set(mrb, btn_mrb_buffer, i, mrb_nil_value());
    input_buf.buffer[i] = 0; i ++ ;
  }

  return mrb_nil_value();
}

static mrb_value start_controller_reader(mrb_state *mrb, mrb_value self) {
  thd_create(1, read_buttons, NULL);

  // start thread
  return mrb_fixnum_value(0);
}

static mrb_value get_current_ms(mrb_state *mrb, mrb_value self) {
    return mrb_fixnum_value(timer_ms_gettime64());
}

static mrb_value put_pixel640(mrb_state *mrb, mrb_value self) {
  mrb_int x, y, r, g, b;
  mrb_get_args(mrb, "iiiii", &x, &y, &r, &g, &b);

  vram_s[x + y * 640] = PACK_PIXEL(r, g, b);

  return mrb_nil_value();
}

static mrb_value waitvbl(mrb_state *mrb, mrb_value self) {
  vid_waitvbl();

  return mrb_nil_value();
}

static mrb_value get_next_button_state(mrb_state *mrb, mrb_value self) {
  mrb_int wanted_index;
  mrb_get_args(mrb, "i", &wanted_index);
  int curr_index = input_buf.index;

  if(wanted_index >= BUFSIZE || wanted_index < 0) { wanted_index = wanted_index % BUFSIZE; }

  // TODO: this will break if processing is slow and current catches up with wanted - 1
  // So this should overwrite just-read values with null.
  if(wanted_index == (curr_index + 1) % BUFSIZE) {
    return mrb_nil_value();
  } else {
    return mrb_fixnum_value(input_buf.buffer[wanted_index]);
  }
}

void draw_rect_640(int x, int y, int w, int h, int r, int g, int b) {
  int i = 0, j = 0;

  for(i = 0; i < h; i++) {
    for(j = 0; j < w; j++) {
      if(i == 0 || j == 0 || i == h - 1 || j == w - 1) {
        vram_s[x+j + (y+i) * 640] = PACK_PIXEL(r, g, b);
      }
    }
  }
}

static mrb_value draw_rectangle_640(mrb_state *mrb, mrb_value self) {
  mrb_int x, y, w, h, r, g, b;
  mrb_get_args(mrb, "iiiiiii", &x, &y, &w, &h, &r, &g, &b);

  draw_rect_640(x, y, w, h, r, g, b);

  return mrb_nil_value();
}

void fill_rect_640(x, y, w, h, r, g, b) {
  int i = 0, j = 0;

  for(i = 0; i < h; i++) {
    for(j = 0; j < w; j++) {
      vram_s[x+j + (y+i) * 640] = PACK_PIXEL(r, g, b);
    }
  }
}

static mrb_value fill20x20_640(mrb_state *mrb, mrb_value self) {
  mrb_int x, y, r, g, b;
  mrb_get_args(mrb, "iiiii", &x, &y, &r, &g, &b);

  fill_rect_640(x, y, 20, 20, r, g, b);

  return mrb_nil_value();
}

static mrb_value fill_rectangle_640(mrb_state *mrb, mrb_value self) {
  mrb_int x, y, w, h, r, g, b;
  mrb_get_args(mrb, "iiiiiii", &x, &y, &w, &h, &r, &g, &b);

  fill_rect_640(x, y, w, h, r, g, b);

  return mrb_nil_value();
}

static mrb_value draw_letter_640(mrb_state *mrb, mrb_value self) {
  const int PX_PER_LINE = 640;
  mrb_int x, y, r, g, b, bg_on;
  char *unwrapped_content;
  mrb_value str_content;

  mrb_get_args(mrb, "Siiiiii", &str_content, &x, &y, &r, &g, &b, &bg_on);
  unwrapped_content = mrb_str_to_cstr(mrb, str_content);

  // assuming 16 bit colours
  bfont_draw_str_ex(vram_s + x + (y * PX_PER_LINE), PX_PER_LINE, PACK_PIXEL(r, g, b), 0x00000000, (sizeof (uint16)) << 3, bg_on, unwrapped_content);

  return mrb_nil_value();
}

static mrb_value get_button_state(mrb_state *mrb, mrb_value self) {
  maple_device_t *cont1;
  cont_state_t *state;
  if((cont1 = maple_enum_type(0, MAPLE_FUNC_CONTROLLER))){
    state = (cont_state_t *)maple_dev_status(cont1);
    return mrb_fixnum_value(state->buttons);
  }
  return mrb_nil_value();
}

static mrb_value check_btn(mrb_state *mrb, mrb_value self, uint16 target) {
  struct mrb_value state;
  mrb_get_args(mrb, "i", &state);

//  if(mrb_fixnum(state)) {
//    printf("state: %ld, target: %d, result: %ld\n", mrb_fixnum(state), target, mrb_fixnum(state) & target);
//  }
  return mrb_bool_value(mrb_fixnum(state) & target);
}

static mrb_value btn_start(mrb_state *mrb, mrb_value self) {
  return check_btn(mrb, self, CONT_START);
};

static mrb_value btn_a(mrb_state *mrb, mrb_value self) {
  return check_btn(mrb, self, CONT_A);
};

static mrb_value btn_b(mrb_state *mrb, mrb_value self) {
  return check_btn(mrb, self, CONT_B);
};

static mrb_value dpad_down(mrb_state *mrb, mrb_value self) {
  return check_btn(mrb, self, CONT_DPAD_DOWN);
};

static mrb_value dpad_up(mrb_state *mrb, mrb_value self) {
  return check_btn(mrb, self, CONT_DPAD_UP);
};

static mrb_value dpad_right(mrb_state *mrb, mrb_value self) {
  return check_btn(mrb, self, CONT_DPAD_RIGHT);
};

static mrb_value dpad_left(mrb_state *mrb, mrb_value self) {
  return check_btn(mrb, self, CONT_DPAD_LEFT);
};

void print_exception(mrb_state* mrb) {
  if(mrb->exc) {
    mrb_value backtrace = mrb_get_backtrace(mrb);
    puts(mrb_str_to_cstr(mrb, mrb_inspect(mrb, backtrace)));

    mrb_value obj = mrb_funcall(mrb, mrb_obj_value(mrb->exc), "inspect", 0);
    fwrite(RSTRING_PTR(obj), RSTRING_LEN(obj), 1, stdout);
    putc('\n', stdout);
  }
}

void define_module_functions(mrb_state* mrb, struct RClass* module) {
  mrb_define_module_function(mrb, module, "put_pixel640", put_pixel640, MRB_ARGS_REQ(5));
  mrb_define_module_function(mrb, module, "fill20x20_640", fill20x20_640, MRB_ARGS_REQ(5));
  mrb_define_module_function(mrb, module, "draw_rectangle_640", draw_rectangle_640, MRB_ARGS_REQ(7));
  mrb_define_module_function(mrb, module, "draw_letter_640", draw_letter_640, MRB_ARGS_REQ(7));
  mrb_define_module_function(mrb, module, "fill_rectangle_640", fill_rectangle_640, MRB_ARGS_REQ(7));
  mrb_define_module_function(mrb, module, "waitvbl", waitvbl, MRB_ARGS_NONE());
  mrb_define_module_function(mrb, module, "get_button_state", get_button_state, MRB_ARGS_NONE());
  mrb_define_module_function(mrb, module, "btn_start?", btn_start, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, module, "btn_a?", btn_a, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, module, "btn_b?", btn_b, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, module, "dpad_down?", dpad_down, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, module, "dpad_up?", dpad_up, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, module, "dpad_right?", dpad_right, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, module, "dpad_left?", dpad_left, MRB_ARGS_REQ(1));

}
