#!/usr/bin/env -S vala --pkg gtk4 --pkg posix --pkg gtk4-layer-shell-0 sharputils.vala debug.vala

namespace SharpUtils {
    public class BTData {
        public Array<HashTable<string, string>> controllers;
        public Array<HashTable<string, string>> devices;
    }
    public class BT : Farm<BTData?> {
        private Subprocess ScanSubprocess;
        public new string name = "BT";

        public enum Actions {
            CONTROLLER_POWER,
            CONTROLLER_DISCOVERABLE,
            CONTROLLER_PAIRABLE,
            DEVICE_PAIR,
            DEVICE_TRUST,
            DEVICE_BLOCK,
            DEVICE_CONNECT,
            DEVICE_REMOVE,
            SCAN
        }
        public async void scan(){
            try {
                ScanSubprocess = new Subprocess.newv(
                    {"bluetoothctl","-t","15","scan","on"},
                    SubprocessFlags.STDERR_PIPE | SubprocessFlags.STDOUT_SILENCE
                );
                yield ScanSubprocess.wait_async();
                ScanSubprocess = null;
            } catch (Error e) {SharpDebug.fail(e.message);}
        }
        public async void action(
            Actions Action,
            bool _bool = true,
            string? mac = null
            ){
            switch (Action) {
                case CONTROLLER_POWER:
                    if (_bool) 
                        yield run_async({"bluetoothctl","power","on"},true);
                    else 
                        yield run_async({"bluetoothctl","power","off"},true);
                    plant();
                    break;
                case CONTROLLER_DISCOVERABLE:
                    if (_bool) yield run_async(
                        {"bluetoothctl","discoverable","on"}, true
                    );
                    else yield run_async(
                        {"bluetoothctl","discoverable","off"}, true
                    );
                    plant();
                    break;
                case CONTROLLER_PAIRABLE:
                    if (_bool) yield run_async(
                        {"bluetoothctl","pairable","on"}, true
                    );
                    else yield run_async(
                        {"bluetoothctl","pairable","off"}, true
                    );
                    plant();
                    break;
                case DEVICE_PAIR:
                    if (_bool) yield run_async(
                        {"bluetoothctl","pair",@"$(mac)"}, true
                    );
                    else yield run_async(
                        {"bluetoothctl","unpair",@"$(mac)"}, true
                    );
                    plant();
                    break;
                case DEVICE_TRUST:
                    if (_bool) yield run_async(
                        {"bluetoothctl","trust",@"$(mac)"}, true
                    );
                    else yield run_async(
                        {"bluetoothctl","untrust",@"$(mac)"}, true
                    );
                    plant();
                    break;
                case DEVICE_BLOCK:
                    if (_bool) yield run_async(
                        {"bluetoothctl","block",@"$(mac)"}, true
                    );
                    else yield run_async(
                        {"bluetoothctl","unblock",@"$(mac)"}, true
                    );
                    plant();
                    break;
                case DEVICE_CONNECT:
                    if (_bool) yield run_async(
                        {"bluetoothctl","connect",@"$(mac)"}, true
                    );
                    else yield run_async(
                        {"bluetoothctl","disconnect",@"$(mac)"}, true
                    );
                    plant();
                    break;
                case DEVICE_REMOVE:
                    if (_bool) yield run_async(
                        {"bluetoothctl","remove",@"$(mac)"}, true
                    );
                    plant();
                    break;
                case SCAN:
                    if (_bool){
                        if (ScanSubprocess == null) scan.begin(); 
                    }
                    else {
                        if (ScanSubprocess != null) ScanSubprocess.force_exit();
                    } 
                    plant();
                    break;
            }
        }
        public override BTData? harvest(){
            if (!SharpUtils.is_program("bluetoothctl")) return null;

            string[] controllers_cmd = {"bluetoothctl" ,"list"};
            string[] controllers_info_cmd_prefix = {"bluetoothctl" ,"show"};
            string[] devices_cmd = {"bluetoothctl" ,"devices"};
            string[] devices_info_cmd_prefix = {"bluetoothctl" ,"info"};
            
            var controller_out = run(controllers_cmd);
            if (controller_out == null) return null;
            var _BTData = new BTData(){
                controllers = new Array<HashTable<string,string>>(),
                devices = new Array<HashTable<string,string>>()
            };

            // Controller
            // ==========
            foreach (var line in controller_out.split("\n")) {
                var tok = SharpUtils.tokenize(line, 3); 
                if (tok == null) continue;

                string is_default = "no";
                if (tok.length >= 4 && tok[(tok.length - 1)] == "[default]" ){
                    is_default = "yes";
                }

                var controller = new HashTable<string, string>(
                    str_hash,str_equal
                );

                controller.insert("mac", tok[1]);
                string alias = ""; for (var i = 2; i < tok.length; i++){
                    if (tok[i] == "[default]") break;
                    alias += "%s ".printf(tok[i]);
                } 
                controller.insert("alias", alias.strip());
                controller.insert("is_default", is_default);
                _BTData.controllers.append_val(controller);
            }
            for (var i = 0; i < _BTData.controllers.length; i++){
                var ctrl = _BTData.controllers.index(i).lookup("mac");
                var controller_info_cmd = controllers_info_cmd_prefix ;
                controller_info_cmd += ctrl;

                var controller_info_out = run(controller_info_cmd);
                if (controller_info_out == null) continue;

                foreach (var line in controller_info_out.split("\n")){
                    var tok = SharpUtils.tokenize(line, 2);
                    if (tok == null) continue;

                    switch (tok[0]) {
                        case "Powered:":
                            _BTData.controllers.index(i)
                                .insert("is_powered", tok[1]); 
                            break;
                        case "Discoverable:":
                            _BTData.controllers.index(i)
                                .insert("is_discoverable", tok[1]); 
                            break;
                        case "Pairable:":
                            _BTData.controllers.index(i)
                                .insert("is_pairable", tok[1]); 
                            break;
                        case "Discovering:":
                            _BTData.controllers.index(i)
                                .insert("is_discovering", tok[1]); 
                            break;
                    } 
                }
            }
            // Devices 
            // =======
            var devices_out = run(devices_cmd);
            if (devices_out == null) return null;

            foreach (var line in devices_out.split("\n")) {
                var tok = SharpUtils.tokenize(line, 3);
                if (tok == null) continue;
                
                var device = new HashTable<string, string>(str_hash,str_equal);

                device.insert("mac", tok[1]);
                string name = ""; for (var i = 2; i < tok.length; i++){
                    name += "%s ".printf(tok[i]);
                } 
                device.insert("name", name.strip());
                _BTData.devices.append_val(device);
            }
            for (var i = 0; i < _BTData.devices.length; i++){
                var dev = _BTData.devices.index(i).lookup("mac");
                var device_info_cmd = devices_info_cmd_prefix;  
                device_info_cmd += dev;

                var devices_info_out = run(device_info_cmd);
                if (devices_info_out == null) continue;

                var is_audio_device = "no";

                foreach (var line in devices_info_out.split("\n")){
                    var tok = SharpUtils.tokenize(line, 2);
                    if (tok == null) continue;

                    switch (tok[0]) {
                        case "Paired:":
                            _BTData.devices.index(i).insert("is_paired",tok[1]); 
                            break;
                        case "Bonded:":
                            _BTData.devices.index(i).insert("is_bonded",tok[1]); 
                            break;
                        case "Trusted:":
                            _BTData.devices.index(i).insert("is_trusted",tok[1]); 
                            break;
                        case "Blocked:":
                            _BTData.devices.index(i).insert("is_blocked",tok[1]); 
                            break;
                        case "Connected:":
                            _BTData.devices.index(i)
                                .insert("is_connected",tok[1]); 
                            break;
                        case "Battery:":
                            var s = tok[1].index_of_char('(');
                            var e = tok[1].index_of_char(')');
                            var battery_perc = tok[1].slice(s,e);
                            _BTData.devices.index(i).insert(
                                "battery_perc", battery_perc
                            ); 
                            break;
                    } 
                    if (tok.length >= 3){
                        string value = "" ; for (var j = 1; j < tok.length; j++){
                            value += "%s ".printf(tok[j]);
                        }
                        if (value.contains("Audio Sink") ||
                            value.contains("Advanced Audio")) {
                            is_audio_device = "yes";
                        }
                        _BTData.devices.index(i).insert(
                            "is_audio_device",
                            is_audio_device
                        ); 
                    }
                }
            }
            return _BTData;
        }
    }
}
