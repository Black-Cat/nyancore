pub const Widget = struct {
    const WidgetFunc = *const fn (self: *Widget) (void);

    init: WidgetFunc,
    draw: WidgetFunc,
    deinit: WidgetFunc,
};
