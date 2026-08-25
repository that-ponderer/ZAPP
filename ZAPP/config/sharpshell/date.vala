#!/usr/bin/env -S vala --pkg gtk4 --pkg gtk4-layer-shell-0 sharputils.vala

namespace SharpUtils {
    public class DateData {
        public string date;
    }
    public class Date: Farm<DateData?> {
        public string date_str = "%r";
        public new string name = "Date";

        public override DateData? harvest(){
            if (!SharpUtils.is_program("date")) return null;
            var date_out = run({"date",@"+$(date_str)"});
            if (date_out == null) return null;
            var _DataData = new DateData(){
                date = date_out.strip()
            };
            return _DataData;
        }
    }
}
