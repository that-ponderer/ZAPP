#!/usr/bin/env -S vala --vapidir=./vapi/ --pkg gtk4 --pkg json-glib-1.0 --pkg gtk4-layer-shell-0 --pkg posix --pkg graphene-gobject-1.0 --pkg gee-0.8 --pkg livechart-2 debug.vala sharputils.vala sway.vala topbar.vala date.vala cpu.vala temp.vala mem.vala storage.vala net.vala bat.vala sharpshell.vala 

namespace SharpShell {
    public class TopBar : Gtk.ApplicationWindow {
        // Consts 
        private SharpShell SharpShell;
        private uint       BorderHeight;
        private uint       FocusedWorkSpaceTitleLength;
        private uint       FocusedWorkSpaceTitleScrollInterval; // (us)
        
        // Farms
        private SharpUtils.Sway     Sway;
        private SharpUtils.Date     Date;
        private SharpUtils.CPU      CPU;
        private SharpUtils.Temp     Temp;
        private SharpUtils.Mem      Mem;
        private SharpUtils.Storage  Storage;
        private SharpUtils.Net      Net;
        private SharpUtils.Bat      Bat;

        public signal void present_border();
        public signal void update_border();

        public class ButtonWithLabel: Gtk.Button {
            public new Gtk.Label label = new Gtk.Label(null);
            public ButtonWithLabel(){
                set_child (label); 
            }
        }
        private class BindingStateWidget: ButtonWithLabel {
            public BindingStateWidget(SharpUtils.Sway _Sway) {
                add_css_class("binding_state_widget");
                _Sway.feed.connect ((_SwayData)=>{
                    if (_SwayData.binding_state == "resize"){
                        label.set_text ("[R]");
                        css_classes = {
                            "binding_state_widget",
                            "binding_state_widget_resize"
                        };
                    }
                    else {
                        label.set_text ("[D]");
                        css_classes = {
                            "binding_state_widget",
                            "binding_state_widget_default"
                        };
                    }
                });
            }
        }
        private class WorkSpacesWidget: Gtk.Box {
            public WorkSpacesWidget(SharpUtils.Sway _Sway){
                // Note: base() works only for constructors defined in vala, not 
                // for translated ones like Gtk.Box(). use Object()
                Object(
                    orientation:Gtk.Orientation.HORIZONTAL,
                    spacing:0
                );
                css_classes = {"workspaces_widget"};

                _Sway.feed.connect ((_SwayData)=>{
                    // Remove all children
                    while (get_first_child () != null){
                        remove (get_first_child ());
                    }
                    // Populate children
                    _SwayData.ws_array.foreach ((num)=>{

                        var button = new ButtonWithLabel ();
                        button.label.set_text (@"$(num)");
                        button.css_classes =  {"button"};
                        button.clicked.connect(()=>{
                            _Sway.action(
                                SharpUtils.Sway.Actions.SET_WORKSPACE, num
                            );
                        });

                        append (button);

                        // handle focused ws
                        if (_SwayData.ws_focused == num){
                            button.css_classes = {
                                "button",
                                "button_focused"
                            };
                        }
                        // handle urgent ws
                        if (_SwayData.ws_urgent.find (num)){
                            button.css_classes = {
                                "button",
                                "button_urgent"
                            };
                        }
                    });
                });
            }
        }
        private class TimeWidget:ButtonWithLabel {
            public TimeWidget(SharpUtils.Date _Date) {
                _Date.feed.connect ((_DateData)=>{
                    css_classes = {"time_widget"}; 
                    label.set_text (_DateData.date);
                });
            }
        }
        private class CalenderWidget : Gtk.ApplicationWindow {
            public enum States {VISIBLE,HIDDEN}
            private States State = States.HIDDEN;
            private TimeWidget   TimeWidget;
            private TopBar       TopBar;
            private Gtk.Calendar Calender;

            public CalenderWidget(
                Gtk.Application _Application,
                TopBar          _TopBar,
                TimeWidget      _TimeWidget
                ) {
                Object(application: _Application); 
                css_classes = {"calender_widget"};
                TimeWidget     = _TimeWidget;
                TopBar         = _TopBar;
                Calender = new Gtk.Calendar();
                Calender.css_classes = {"calender"};

                GtkLayerShell.init_for_window (this);
                GtkLayerShell.set_anchor (this,GtkLayerShell.Edge.TOP,true);
                GtkLayerShell.set_anchor (this,GtkLayerShell.Edge.LEFT,true);

                set_child(Calender);

                TimeWidget.clicked.connect(()=>{
                    toggle();
                });
            }
            public void toggle(){
                switch (State) {
                    case States.HIDDEN:
                        State = States.VISIBLE;
                        present();
                        Calender.set_date (new DateTime.now_local ());

                        var rect_time = Graphene.Rect.zero () ;
                        TimeWidget.compute_bounds (TopBar,out rect_time);
                        var rect_time_center_x = (int) rect_time.get_center ().x;

                        var rect_calender = Graphene.Rect.zero ();
                        var rect_calender_center_x = 0;
                        // positions the calender centered below button_time
                        Idle.add (()=>{
                            // Broute force check for change, gtk does not have a
                            // FUCKING signal for it for some reason 
                            while (rect_calender_center_x == 0){
                                compute_bounds (this, out rect_calender);
                                rect_calender_center_x =
                                    (int) rect_calender.get_center ().x;
                            }
                            var margin_calender = 
                                (rect_time_center_x - rect_calender_center_x);
                            GtkLayerShell.set_margin (
                                this,GtkLayerShell.Edge.LEFT,
                                margin_calender
                            );
                            return false;
                        });
                        break;
                    case States.VISIBLE:
                        State = States.HIDDEN;
                        hide();
                        break;
                }
            }
        }
        private class CPUWidget : ButtonWithLabel {
            public CPUWidget(SharpUtils.CPU _CPU) {
                css_classes = {"cpu_widget"};
                _CPU.feed.connect((_CPUData)=>{
                    var cpu_perc = "%.1lf".printf(_CPUData.usage_avg);
                    label.set_text ("%s%|".printf(cpu_perc));
                });
            } 
        }
        private class TempWidget : ButtonWithLabel {
            public TempWidget(SharpUtils.Temp _Temp){
                css_classes = {"temp_widget"};
                _Temp.feed.connect((_TempData)=>{
                    var cpu_temp = 
                        _TempData.data.lookup("cpu").lookup("inputs")[0];
                    var cpu_perc = int.parse(cpu_temp) / 1000;
                    if (cpu_perc <= 40){
                        label.set_text ("%d°C|".printf (cpu_perc));
                    }
                    else if (cpu_perc <= 60){
                        label.set_text ("%d°C|".printf (cpu_perc));
                    }
                    else {
                        label.set_text ("%d°C|".printf (cpu_perc));
                    }
                });
            }
        }
        private class MemWidget : ButtonWithLabel {
            public MemWidget(SharpUtils.Mem _Mem){
                css_classes = {"mem_widget"};
                _Mem.feed.connect((_MemData)=>{
                    var mem_usage_perc = ((double) _MemData.mem_usage)
                                          / _MemData.mem_total * 100 ;  
                    label.set_text ("%.1lf%|".printf (mem_usage_perc));
                });
            }
        }
        private class StorageWidget : ButtonWithLabel {
            public StorageWidget(SharpUtils.Storage _Storage){
                css_classes = {"storage_widget"};
                _Storage.feed.connect((_StorageData)=>{
                    HashTable<string, string> root_fs = null; 
                    _StorageData.data.foreach ((k,v)=>{
                        if (v.lookup ("mounted_on") == "/") {
                            root_fs = v;
                            return;
                        }
                    });
                    if (root_fs != null){
                        var storage_usage_perc = double.parse (
                            root_fs.lookup ("storage_usage")
                        ) / double.parse (
                            root_fs.lookup ("storage_total")) * 100;
                        label.set_text ("%.1lf%|󰝰".printf (
                            storage_usage_perc));
                    }
                });
            }
        }
        private class NetWidget : ButtonWithLabel {
            public NetWidget(SharpUtils.Net  _Net){
                css_classes = {"net_widget"};
                _Net.feed.connect((_NetData)=>{
                    long top_up_speed = 0;
                    long top_down_speed = 0;
                    _NetData.net_up_speed.foreach ((k,v)=>{
                        if (v > top_up_speed) top_up_speed = v;
                    });
                    _NetData.net_down_speed.foreach ((k,v)=>{
                        if (v > top_down_speed) top_down_speed = v;
                    });
                    label.set_text ("%ldKiB||%ldKiB|".printf (
                        top_down_speed / 1024,
                        top_up_speed / 1024
                    ));
                });
            }
        }
        private class BatWidget : ButtonWithLabel {
            public BatWidget(SharpUtils.Bat _Bat){
                css_classes = {"bat_widget"};
                _Bat.feed.connect((_BatData)=>{
                    var battery = _BatData.data.lookup ("BAT1"); 
                    if ( battery != null){
                        var battery_status = battery.lookup ("status");
                        var battery_perc = battery.lookup ("capacity"); 
                        var label_bat_icon = "";
                        switch (battery_status) {
                            case "Full":
                                label_bat_icon = "";
                                break;
                            case "Charging":
                                label_bat_icon = "";
                                break;
                            case "Discharging":
                                if (int.parse (battery_perc) <= 20){
                                    label_bat_icon = "";
                                }
                                else if (int.parse (battery_perc) <= 40){
                                    label_bat_icon = "";
                                }
                                else if (int.parse (battery_perc) <= 60){
                                    label_bat_icon = "";
                                }
                                else if (int.parse (battery_perc) <= 80){
                                    label_bat_icon = "";
                                }
                                else {
                                    label_bat_icon = "";
                                }
                                break;
                            default:
                                label_bat_icon = "";
                                break;
                        }
                        label.set_text ("%s%%|%s".printf (
                            battery_perc,
                            label_bat_icon
                        )); 
                    }
                });
            }
        }
        private class Border : Gtk.ApplicationWindow{
            public Border(
                Gtk.Application _Application,
                TopBar _TopBar,
                uint _BorderHeight
                ){
                css_classes = {"topbar_border"}; 
                default_height = (int) _BorderHeight;

                GtkLayerShell.init_for_window (this);
                GtkLayerShell.auto_exclusive_zone_enable (this);
                GtkLayerShell.set_anchor (this,GtkLayerShell.Edge.TOP,  true);
                GtkLayerShell.set_anchor (this,GtkLayerShell.Edge.LEFT, true);
                GtkLayerShell.set_anchor (this,GtkLayerShell.Edge.RIGHT,true);

                _TopBar.present_border.connect(()=>{
                    present();
                });
                _TopBar.update_border.connect(()=>{
                    hide();
                    present();
                });
            }
        }
        private class FocusedWorkSpaceTitleWidget : Gtk.Box {
            private Regex     ExclusionRegex; 
            private Gtk.Label Label;
            public FocusedWorkSpaceTitleWidget(
                SharpUtils.Sway _Sway,
                uint            _FocusedWorkSpaceTitleLength,
                uint            _FocusedWorkSpaceTitleScrollInterval
                ){
                orientation    = Gtk.Orientation.HORIZONTAL;
                spacing        = 0;
                try {
                    ExclusionRegex = new Regex("^[0-9]+$");
                    Label          = new Gtk.Label(null);
                    append(Label);
                    css_classes = {"focused_ws_title_widget"};
                    _Sway.feed.connect((_SwayData)=>{
                        if (_SwayData.focused_ws_title == null) 
                            return;
                        var text = SharpUtils.scroll_text (
                            _SwayData.focused_ws_title,
                            _FocusedWorkSpaceTitleLength,
                            _FocusedWorkSpaceTitleScrollInterval,
                            " ","","..."
                        );
                        if (!ExclusionRegex.match (text)){
                            Label.set_text(text);
                        } else {
                            Label.set_text("");
                        } 
                    });
                } catch (RegexError e) {SharpDebug.fail(e.message);}
            }
        }
        public TopBar (
            SharpShell _SharpShell,
            SharpUtils.Sway     _Sway,
            SharpUtils.Date     _Date,
            SharpUtils.CPU      _CPU,
            SharpUtils.Temp     _Temp,
            SharpUtils.Mem      _Mem,
            SharpUtils.Storage  _Storage,
            SharpUtils.Net      _Net,
            SharpUtils.Bat      _Bat,
            int                 _BorderHeight = 2,
            uint                _FocusedWorkSpaceTitleLength = 50,
            uint                _FocusedWorkSpaceTitleScrollInterval = 1000000
            ) {
            // Construction
            application                 = _SharpShell;
            SharpShell                  = _SharpShell;
            Sway                        = _Sway;
            Date                        = _Date;
            CPU                         = _CPU;
            Temp                        = _Temp;
            Mem                         = _Mem;
            Storage                     = _Storage;
            Net                         = _Net;
            Bat                         = _Bat;
            BorderHeight                = _BorderHeight;
            FocusedWorkSpaceTitleLength = _FocusedWorkSpaceTitleLength;
            FocusedWorkSpaceTitleScrollInterval 
                = _FocusedWorkSpaceTitleScrollInterval;

            add_css_class ("topbar");

            // Set as shell layer
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.auto_exclusive_zone_enable (this);
            GtkLayerShell.set_anchor (this,    GtkLayerShell.Edge.TOP,   true);
            GtkLayerShell.set_anchor (this,    GtkLayerShell.Edge.LEFT,  true);
            GtkLayerShell.set_anchor (this,    GtkLayerShell.Edge.RIGHT, true);
            // .____________.
            // | Structure |
            // `````````````
            var centerbox = new Gtk.CenterBox ();
            var left = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            var middle = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            var right = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            right.set_halign (Gtk.Align.END); 
            centerbox.set_start_widget (left);
            centerbox.set_center_widget (middle);
            centerbox.set_end_widget (right);
            set_child (centerbox);
            // ._______________.
            // | Binding State |
            // `````````````````
            var binding_state_widget = new BindingStateWidget (Sway);
            left.append (binding_state_widget);
            // .____________.
            // | Workspaces |
            // ``````````````
            var workspaces_widget = new WorkSpacesWidget (Sway);
            left.append (workspaces_widget);
            // .__________________.
            // | Focused WS title |
            // ````````````````````
            var focused_ws_title_widget = new FocusedWorkSpaceTitleWidget(
                Sway, 
                FocusedWorkSpaceTitleLength, 
                FocusedWorkSpaceTitleScrollInterval
            );
            left.append(focused_ws_title_widget);
            // .______.
            // | Time |
            // ````````
            var time_widget = new TimeWidget (Date);
            middle.append (time_widget);
            // .__________.
            // | Calender | 
            // ````````````
            new CalenderWidget(SharpShell,this,time_widget);
            // .________.
            // | Others |
            // ``````````
            // cpu
            var cpu_widget = new CPUWidget(CPU);
            right.append(cpu_widget);
            // temp 
            var temp_widget = new TempWidget(Temp);
            right.append(temp_widget);
            // mem 
            var mem_widget = new MemWidget(Mem);
            right.append(mem_widget);
            // storage 
            var storage_widget = new StorageWidget(Storage);
            right.append(storage_widget);
            // net 
            var net_widget = new NetWidget(Net);
            right.append(net_widget);
            // bat
            var bat_widget = new BatWidget(Bat);
            right.append(bat_widget);
            // border
            new Border(SharpShell, this, BorderHeight);
        }
    }
}
