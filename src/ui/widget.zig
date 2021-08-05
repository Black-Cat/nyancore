pub const Widget = struct {
    const WidgetFunc = fn (self: *Widget) (void);

    init: WidgetFunc,
    draw: WidgetFunc,
    deinit: WidgetFunc,
};
