inherit MMP.Base : B;
inherit Serialization.Signature;
inherit PSYC.PsycTypes;

object message_signature;

void create(object server, MMP.Uniform uniform) {
    B::create(server, uniform);
    //S::create(server->type_cache);

    message_signature = Message(); // whatever
}


void msg(MMP.Packet p) {
    if (!::msg(p)) return; // drop old packets

    if (message_signature->can_decode(p->data)) { // this is a psyc mc or something
	string method = p->data->type;
	PSYC.Message m;

	if (method[0] == '_') {
	    mixed f = this[method];
	    
	    if (functionp(f)) {
		if (!m) m = message_signature->decode(p->data);
		if (PSYC.STOP == f(p, m)) return;
	    }

	    array(string) t = method/"_";

	    for (int i = sizeof(t)-2; i > 0; i--) {
		f = this[t[0..i]*"_"];
		if (functionp(f)) {
		    if (!m) m = message_signature->decode(p->data);
		    if (PSYC.STOP == f(p, m)) return;
		}
	    }

	    f = this->_;

	    if (functionp(f)) {
		if (!m) m = message_signature->decode(p->data);
		if (PSYC.STOP == f(p, m)) return;
	    }
	}
    }
}

void sendmsg(MMP.Uniform target, string method, void|string data, void|mapping m) {
	send(target, message_signature->encode(PSYC.Message(method, data, m)));
}

int _request_retrieval(MMP.Packet p, PSYC.Message m) {
    array ids = m["_ids"];
    werror("%O: _request_retrieval(%d) of %O\n", p->source(), p["_id"], ids);

    object state = get_state(p->source());

    foreach (ids;;int i) {
	MMP.Packet packet = state->cache[i];
	werror("retransmission of %d\n", i);
	if (!packet) werror("Packet with id %d not available for retransmission\n", i);
	else server->msg(packet);
    }

    return PSYC.GOON;
}

int _message_public(MMP.Packet p, PSYC.Message m) {
    werror("%O: _message_public(%d)\n", uniform, p["_id"]);
}