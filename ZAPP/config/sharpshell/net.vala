#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0 sharputils.vala
namespace SharpUtils {
    public class NetData {
        public HashTable<string,string> net_dev_state;
        public HashTable<string,string> net_link_state;
        public HashTable<string,long> net_down_speed;
        public HashTable<string,long> net_up_speed;
        public HashTable<string,Array<string>> net_ip_addr;
        public HashTable<string,Array<string>> net_gate;
    }
    public class Net : Farm<NetData?> {
        public new string name = "Net";
        private ulong Interval;
        public Net(ulong _Interval = 1000000){
            Interval = _Interval;
        }
        private class NET_Link {
            public HashTable<string,string> net_dev_state;
            public HashTable<string,string> net_link_state;
            public HashTable<string,long>   net_down_total;
            public HashTable<string,long>   net_up_total;

            public static NET_Link? fetch (){
                if (!SharpUtils.is_program ("ip")) return null;
                string[] link_cmd = {"ip","-o","-s","link"};
                var out = run(link_cmd);
                if (out == null) return null;

                var _NET_Link = new NET_Link (){
                    net_dev_state = new HashTable<string,string>(
                        str_hash,str_equal
                    ),
                    net_link_state = new HashTable<string,string>(
                        str_hash,str_equal
                    ),
                    net_down_total = new HashTable<string,long>(
                        str_hash,str_equal
                    ),
                    net_up_total = new HashTable<string,long>(str_hash,str_equal)
                };

                foreach (var line in out.split("\n")) {
                    var tok = SharpUtils.tokenize (line, 8);
                    if (tok == null) continue;

                    // skip loopback
                    string dev = tok[1].replace(":", "");
                    if (dev == "lo") continue;

                    _NET_Link.net_dev_state.insert(
                        dev,
                        tok[2].contains("UP") ? "UP" : "DOWN"
                    );
                    _NET_Link.net_link_state.insert(
                        dev,
                        tok[8]
                    );
                    // Abandon if not connected
                    if (tok[8] != "UP") continue;
                    
                    for (int i = 0; i < tok.length; i++) {
                        if (tok[i] == "RX:" && i + 8 < tok.length) {
                            _NET_Link.net_down_total.insert(
                                dev,
                                long.parse(tok[i + 8])
                            );
                        }
                        if (tok[i] == "TX:" && i + 8 < tok.length) {
                            _NET_Link.net_up_total.insert(
                                dev,
                                long.parse(tok[i + 8])
                            );
                        }
                    }
                }
                return _NET_Link;
            }
        }
        private class NET_IP {

            public HashTable<string,Array<string>> net_ip_addr;

            public static NET_IP? fetch(HashTable<string, string> net_dev_state) {
                string[] ip_cmd = {"ip","-o","addr"};
                var out_str = run(ip_cmd);

                if (out_str == null) return null;

                var _NET_IP = new NET_IP (){
                    net_ip_addr = new HashTable<string, Array<string>?>(
                        str_hash,str_equal
                    )
                };

                Regex ipv4_regex; try {
                    ipv4_regex = new Regex(
                        "^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+/[0-9]+$"
                        );
                } catch (RegexError e) {
                    return null;
                }

                foreach (var line in out_str.split("\n")) {
                    string[] tok = {};
                    foreach (var i in line.split(" ")) {
                        if (i != "") tok += i ;
                    }
                    if (tok.length < 4)
                        continue;

                    string dev = tok[1];
                    string ip = tok[3];
                    
                    if (net_dev_state.contains(dev) && ipv4_regex.match (ip)) {
                        var ip_arr = _NET_IP.net_ip_addr.lookup (dev);

                        if (ip_arr == null){
                            ip_arr = new Array<string>();
                        }
                        ip_arr.append_val(ip);
                        _NET_IP.net_ip_addr.replace (dev, ip_arr);
                    }
                }
                return _NET_IP;
            }
        }
        private class NET_Gate {
            public HashTable<string,Array<HashTable<string, string>>?> net_gate;

            public static NET_Gate? fetch(HashTable<string, string> net_dev_state) {
                string[] gate_cmd = {"ip","-o","route"};
                var out_str = run(gate_cmd);

                if (out_str == null) return null;

                var _NET_Gate = new NET_Gate (){
                    net_gate = new HashTable<
                        string, Array<HashTable<string, string>>?>(
                        str_hash,str_equal
                    )
                };
                
                foreach (var line in out_str.split("\n")) {
                    string[] tok = {};
                    foreach (var i in line.split(" ")) {
                        if (i != "") tok += i ;
                    }
                    if (tok.length < 5)
                        continue;

                    string dest = tok[0];
                    if (dest == "default") dest = "0.0.0.0";
                    string gate = tok[2];
                    string dev = tok[4];

                    if (net_dev_state.contains(dev)) {
                        var _gate = _NET_Gate.net_gate.lookup (dev);

                        if (_gate == null){
                            _gate = new Array<HashTable<string, string>>();
                        }

                        var _gate_ht = new HashTable<string, string>(
                            str_hash,str_equal);
                        _gate_ht.insert("dest", dest);
                        _gate_ht.insert("gate", gate);
                        _gate.append_val(_gate_ht);
                        _NET_Gate.net_gate.replace (dev, _gate);
                    }
                }
                return _NET_Gate;
            }
        }
        public override NetData? harvest (){
            if (!SharpUtils.is_program ("ip")) return null;

            var link_start = NET_Link.fetch ();
            Thread.usleep(Interval);
            var link_end = NET_Link.fetch ();

            var ip = NET_IP.fetch (link_end.net_dev_state);
            var gate = NET_Gate.fetch (link_end.net_dev_state);
            
            if (
                link_start == null ||
                link_end == null ||
                ip == null ||
                gate == null 
                ) return null;

            var _NETData = new NetData(){
                net_dev_state = new HashTable<string,string>(str_hash,str_equal),
                net_link_state = new HashTable<string,string>(str_hash,str_equal),
                net_down_speed =  new HashTable<string,long>(str_hash,str_equal),
                net_up_speed =  new HashTable<string,long>(str_hash,str_equal),
                net_ip_addr = new HashTable<string,Array<string>>(str_hash,str_equal),
                net_gate = new HashTable<string,Array<string>>(str_hash,str_equal)
            };
            var net_down_speed = new HashTable<string, long>(str_hash,str_equal);
            var net_up_speed = new HashTable<string, long>(str_hash,str_equal);

            link_start.net_down_total.foreach((dev, net_down_total)=>{
                if (link_end.net_down_total.contains(dev)) {
                    net_down_speed.insert(dev, 
                        link_end.net_down_total.lookup(dev) -  net_down_total);        
                }
                else {
                    return;
                }
            });
            link_start.net_up_total.foreach((dev, net_up_total)=>{
                if (link_end.net_up_total.contains(dev)) {
                    net_up_speed.insert(dev, 
                        link_end.net_up_total.lookup(dev) -  net_up_total);        
                }
                else {
                    return;
                }
            });
            
            _NETData.net_dev_state = link_end.net_dev_state;
            _NETData.net_link_state = link_end.net_link_state;
            _NETData.net_ip_addr = ip.net_ip_addr;
            _NETData.net_down_speed = net_down_speed;
            _NETData.net_up_speed = net_up_speed;

            return _NETData;
        }
    }
}
