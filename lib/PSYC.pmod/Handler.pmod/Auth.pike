// vim:syntax=lpc
#include <debug.h>

inherit PSYC.Handler.Base;

constant _ = ([
    "filter" : ([
	"_notice_authentication" : 0,		      
	"_error_authentication" : 0,		      
	"" : ([ "async" : 1 ]),
    ]),
    "postfilter" : ([
	"_request_authentication" : 0,
    ]),
]);

mapping(MMP.Uniform:MMP.Uniform) unl2uni = ([ ]);
// we may have several people representing the same .. guy. they all want some
// piece of the cake
mapping(MMP.Uniform:MMP.Uniform|array(MMP.Uniform)) uni2unl = ([]);
mapping(MMP.Uniform:mapping(MMP.Uniform:array(function))) pending = ([ ]);

void auth_reply(int s, MMP.Packet p) {
    PSYC.Packet m = p->data;

    if (s) {
	uni->sendmsg(p["_source"], m->reply("_notice_authentication", 0, 
					([ "_location" : m["_location"] ])));	
    } else {
	uni->sendmsg(p["_source"], m->reply("_error_authentication", 0, 
					([ "_location" : m["_location"] ])));	
    }
}

int postfilter_request_authentication(MMP.Packet p, mapping _v) {
    PSYC.Packet m = p->data;

    if (!has_index(m->vars, "_location")) {
	uni->sendmsg(p["_source"], m->reply("_error_invalid_request_authentication", "what???"));
	return PSYC.Handler.STOP;
    }
    
    uni->check_authentication(m["_location"], auth_reply, p);

    return PSYC.Handler.STOP;
}

int filter_error_authentication(MMP.Packet p, mapping _v) {
    PSYC.Packet m = p->data;

    if (!has_index(m->vars, "_location")) {
	P3(("PSYC.Handler.Auth", "incomplete _error_invalid_authentication (_location is missing)\n"))
	return PSYC.Handler.STOP;
    }

    MMP.Uniform source = p["_source"];
    MMP.Uniform location = m["_location"];

    if (has_index(pending, location) && has_index(pending[location], source)) {
	m_delete(pending[location], source)(0);

	P3(("Uni", "I was not able to get authentication for %s (claims to be %s).\n", location, source))

	PSYC.Packet failure = PSYC.Packet("_failure_authentification",
					  "I was unable to verifiy your identification ([_identification]).", ([ "_identification" : source ]));

	uni->sendmsg(location, failure);
    } else {
	P3(("Handler.Auth", "_error_authentication even though we never requested one.\n"))
    }

    return PSYC.Handler.STOP;
}

int filter_notice_authentication(MMP.Packet p, mapping _v) {
    PSYC.Packet m = p->data;

    if (!has_index(m->vars, "_location")) {
	P3(("PSYC.Handler.Auth", "incomplete _notice_authentication (_location is missing)\n"))
	return PSYC.Handler.STOP;
    }

    MMP.Uniform source = p["_source"];
    MMP.Uniform location = m["_location"];
    
    // we dont use that yet
    P3(("Uni", "Successfully authenticated %s as %s.\n", location, source))
    unl2uni[location] = source; 	

    if (has_index(uni2unl, source)) {
	if (arrayp(uni2unl[source]))	
	    uni2unl[source] += ({ location }); 
	else
	    uni2unl[source] = ({ uni2unl[source], location });
    } else uni2unl[source] = location;

    if (has_index(pending, location) && has_index(pending[location], source)) {
	m_delete(pending[location], source)(1);
    }

    return PSYC.Handler.STOP;
}

void filter(MMP.Packet p, mapping _v, function cb) {

    P3(("Auth.Handler", "Handling identification of %O.\n", p->vars))

    if (has_index(p->vars, "_source_identification")) {
	MMP.Uniform id = p["_source_identification"];	
	MMP.Uniform s = p["_source"];

	if (!has_index(unl2uni, s) || (unl2uni[s] != id && m_delete(unl2uni, s))) {
	    if (!has_index(pending, s)) {
		pending[s] = ([]);
	    }

	    if (!has_index(pending[s], id)) {
		pending[s][id] = ({  }); 
    P3(("Auth.Handler", "!!!Handling!!! identification of %O.\n", p))
		PSYC.Packet request = PSYC.Packet("_request_authentication",
						  "nil", 
						  ([ "_location" : s ]));
		uni->sendmsg(id, request);
	    }

	    pending[s][id] += ({ cb }); 
	    return;
	}
    }
    call_out(cb, 0, PSYC.Handler.GOON);
}