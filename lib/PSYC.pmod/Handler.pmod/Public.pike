// vim:syntax=lpc
#include <debug.h>

inherit PSYC.Handler.Base;

//! This Handler may be used for Channels only.
constant _ = ([ 
]);

constant export = ({ "enter", "leave" });

void enter(MMP.Uniform someone, function callback, mixed ... args) {
    PT(("Handler.Public", "%O: %O asks for membership. args: %O\n", this, someone, args))

    parent->castmsg(PSYC.Packet("_notice_context_enter"), someone);
    MMP.Utils.invoke_later(callback, 1, @args);
    parent->handle("notify", "member_entered", someone);
}

void leave(MMP.Uniform someone) {
    parent->castmsg(PSYC.Packet("_notice_context_leave"), someone);
    parent->handle("notify", "member_left", someone);
}