inherit MMP.Utils.UniformCache;

MMP.Circuit out;
string bind_local;

mapping(MMP.Uniform:object) entities = ([]);
mapping(string:MMP.Circuit) circuit_cache = set_weak_flag(([ ]), Pike.WEAK_VALUES);
mapping(string:MMP.VirtualCircuit) vcircuit_cache = ([]);
mapping (string:object) vhosts = ([ ]);

string _sprintf(int type) {
    if (type == 'O') {
	return sprintf("MMP.Server(%O)", bind_local||vhosts);
    }

    error("wrong format.");
}

void circuit_to(string host, int port, function(MMP.Circuit:void) cb) {
    if (!port) port = .DEFAULT_PORT;
    string hip = sprintf("%s:%d", host, port);
    MMP.Circuit t;

    if (t = circuit_cache[hip]) {
	call_out(cb, 0, t);
	return;
    } else if (has_index(vhosts, hip)) {
	call_out(cb, 0, 0);
	return;
    }

    Stdio.File f = Stdio.File();
    if (bind_local) f->open_socket(UNDEFINED, bind_local);

    void connected(int success) {
	if (!success) werror("Could not connect to host %s\n", hip);
	else {
	    MMP.Circuit c;

	    if (has_index(circuit_cache, hip)) {
		c = circuit_cache[hip];
		f->close();
	    } else {
		circuit_cache[hip] = c = MMP.Circuit(f, msg, this, 0);
	    }

	    cb(c);
	}
    };
    
    f->async_connect(host, port, connected);
}

void register_entity(MMP.Uniform u, object o) {
    entities[u] = o;
}

void unregister_entity(MMP.Uniform u) {
    m_delete(entities, u);
}

object get_entity(MMP.Uniform u) {
    return entities[u];
}

void msg(MMP.Packet p, void|object c) {
    object s;
    MMP.Uniform target = p->target();
    string host, hip;
    int port;

    //werror("%O: %s -> %O\n", this, p->data->type, target);

    if (c) {
	// CHECK FOR SANITY
	werror("got: %O from %O\n", p, c);
    }

    if (has_index(entities, target)) {
	// THIS IS ONLY FOR SAFETY REASONS
	call_out(entities[target]->msg, 0, p);
	return;
    }


    host = target->host;
    port = target->port || .DEFAULT_PORT;

    hip = sprintf("%s:%d", host, port);

    if (has_index(vhosts, hip)) {
	mixed s = vhosts[hip];
	if (!s || Program.inherits(object_program(s), MMP.Utils.Aggregator)) {
	    object o = get_entity(target);

	    if (o) o->msg(p);
	    else werror("Dont know how to create object for %O\n", target);
	} else if (s == this) {
	    werror("Failure to deliver: %O\n", p);
	} else {
	    s->msg(p);
	}
    } else {
	werror("Connecting to %O\n", hip);
	MMP.VirtualCircuit v = vcircuit_cache[hip];

	if (!v) vcircuit_cache[hip] = v = MMP.VirtualCircuit(target, this, verror_cb, Function.curry(check_out)(hip));
	v->msg(p);
    }
}

void close(MMP.Circuit c) {
    werror("%O was closed.\n", c);
    m_delete(circuit_cache, c->hip);
}

void verror_cb(mixed ... args) {
    werror("vcircuit error: %O\n", args);
}

void accept(mixed id) {
    Stdio.File f = id->accept();
    MMP.Circuit c = MMP.Circuit(f, msg, this, 1);
    c->add_close_cb(close);
    string hip = c->hip;

    if (has_index(circuit_cache, hip)) {
	werror("An old Vcircuit existed %O. cleaning up.\n", circuit_cache[hip]);
    }

    // got connection from local vhost
    if (has_index(vhosts, hip)) {
	mixed t = vhosts[hip];

	if (t == this) { // we are not vhost anymore
	    m_delete(vhosts, hip);
	} else if (Program.inherits(t, MMP.Utils.Aggregator)) {
	    t->disable();
	    vhosts[hip] = this;
	    if (has_index(circuit_cache, hip)) {
		circuit_cache[hip]->close();
	    }
	}
    }

    // local vhost detection goes here
    string lhip = c->lhip;

    MMP.Utils.Aggregator e;
    if (has_index(vhosts, lhip)) {
	mixed t = vhosts[lhip];
	if (t && Program.inherits(object_program(t), MMP.Utils.Aggregator)) {
	    e = t;
	}
    } else {
	vhosts[lhip] = MMP.Utils.Aggregator(Function.curry(m_delete)(vhosts, lhip));
    }

    if (e) {
	function f = e->get_cb();
	e->done();

	void c_out() {	
	    check_out(hip);
	    f();
	};
	vcircuit_cache[hip] = MMP.VirtualCircuit(get_uniform("psyc://"+hip+"/"), this, verror_cb, c_out, c);
    } else {
	vcircuit_cache[hip] = MMP.VirtualCircuit(get_uniform("psyc://"+hip+"/"), this, verror_cb, Function.curry(check_out)(hip), c);
    }

}

void bind(void|string ip, void|int port) {
    Stdio.Port p = Stdio.Port(port, accept, ip);
    if (p->errno()) {
	werror("Cannot bind port %s:%d: %s\n", ip||"", port, strerror(p->errno()));
    } else {
	p->set_id(p);
	vhosts[replace(p->query_address(), " ", ":")] = this;
    }
}

MMP.Circuit get_route(MMP.Uniform target) {
}

void create(mapping settings) {
    
    if (intp(settings->bind) || stringp(settings->bind)) {
	settings->bind = ({ settings->bind });
    }

    foreach (settings->bind;; string|int t) {
	if (intp(t)) bind(0, t);
	else if (stringp(t)) {
	    string host;
	    int port;

	    sscanf(t, "%[^:]:%d", host, port);
	    if (host && !bind_local) bind_local = host;
	    bind(host, port);
	} else error("Cannot bind to this: %O\n", t);

    }

    if (settings->entitites) foreach(settings->entities; mixed uni; object o) {
	if (stringp(uni)) {
	    MMP.Uniform t;

	    if (t = get_uniform(uni)) {
		register_entity(t, o);
	    } else {
		werror("'%s' is not a valid Uniform.\n");
	    }
	} else {
	    register_entity(stringp(uni) ? get_uniform(uni) : uni, o);
	}
    }

    if (settings->vhosts) foreach(settings->vhosts;; string hip) {
	if (search(hip, ":") == -1) {
	    hip = sprintf("%s:%d", hip, .DEFAULT_PORT);
	}
	add_vhost(hip);
    }

    if (settings->external_vhosts) foreach(settings->external_vhosts; string hip; object server) {
	if (search(hip, ":") == -1) {
	    hip = sprintf("%s:%d", hip, .DEFAULT_PORT);
	}
	add_vhost(hip, server);
    }
}

void add_vhost(string hip, void|object server) {
    vhosts[hip] = server || this;
}

void remove_vhost(string hip) {
    m_delete(vhosts, hip);
}

void check_out(string hip) {
    werror("VirtualCircuit %O checked out.\n", hip);
    //destruct(m_delete(vcircuit_cache, hip)); // TODO:: destruct
    m_delete(vcircuit_cache, hip);
}