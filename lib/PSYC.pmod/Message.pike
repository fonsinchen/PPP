object vsig, dsig;

mapping state, vars;
multiset deleted = (< >);
MMP.Packet mmp_packet;
PSYC.Packet packet;
int id;

object snapshot;

object bridge;

// +===========================================+
// ||                 Message                 ||
// ||=========================================||
// || + vsig : object                         ||
// || + dsig : object                         ||
// || + state : mapping                       ||
// || + vars : mapping                        ||
// || + deleted : multiset                    ||
// || + id : int                              ||
// || + object : bridge                       ||
// ||=========================================||
// ||=========================================||
// || + void assign(mixed, mixed)             ||
// || + void change_state(Serialization.Atom) ||
// || + mixed `[]=(mixed, mixed)              ||
// || + mixed `[](mixed)                      ||
// || + Iterator _get_iterator(void)          ||
// || + mixed `->(mixed)                      ||
// || + mixed `->(mixed, mixed)               ||
// || + void create(mapping)                  ||
// +===========================================+

class Bridge {
    mixed `[](mixed index) {
	if (has_index(vars, index)) return vars[index];
	if (deleted[index]) return UNDEFINED;
	return state[index];
    }

    mixed `[]=(mixed index, mixed value) {
	if (has_index(deleted, index)) deleted[index]--;
	vars[index] = value;
    }

    int(0..1) _has_index(mixed index) {
	return !deleted[index] && has_index(state, index) || has_index(vars, index);
    }

    mixed _m_delete(mixed index) {
	mixed ret;

	if (has_index(state, index)) {
	    ret = state[index];
	    deleted[index]++;
	}

	if (has_index(vars, index)) {
	    ret = m_delete(vars, index);
	}

	return ret;
    }

    Iterator _get_iterator() {
	return BridgeIterator(this);
    }
}

class BridgeIterator {
    inherit Iterator;

    constant STATE = 1;
    constant VARS = 2;

    int mstate = STATE;
    object it;

    void create(void|object iterator) {
	it = iterator || get_iterator(state);
    }

    int(0..1) next() {
	for (;;) {
	    int ret = it->next();

	    if (!ret && mstate == STATE) {
		it = get_iterator(vars);
		mstate = VARS;
		continue;
	    }

	    mixed key = it->index();
	    
	    if (deleted[key]) continue;
	    if (mstate == STATE && has_index(vars, key)) continue;

	    break;
	}
    }

    void first() {
	if (mstate == STATE) {
	    it->first();
	} else {
	    it = get_iterator(state);
	    mstate = STATE;
	}
    }

    mixed index() {
	it->index();
    }

    this_program `+=(int steps) {
	if (steps < 0) error("uhuh");

	while (steps-- > 0) {
	    next();
	}
    }

    this_program `+(int steps) {
	object new_it = this_program(it+0);
	new_it->mstate = mstate;
	new_it += steps; // looks dangerous but is totally safe.. hopefully.
	return new_it;
    }

    mixed value() {
	it->value();
    }

}

void create(mapping params) {
    if (params["vsig"]) vsig = params["vsig"];
    if (params["dsig"]) dsig = params["dsig"];
    if (params["state"]) {
	snapshot = params["snapshot"];
	state = vsig->decode(snapshot->raw_state);
    }
    id = params["id"];
}

mixed `->=(string index, mixed value) {
    switch (index) {
    case "source":
	if (!mmp_packet) mmp_packet = MMP.Packet();
	return mmp_packet->source = value;
    case "target":
	if (!mmp_packet) mmp_packet = MMP.Packet();
	return mmp_packet->target = value;
    case "mc":
	if (!packet) packet = PSYC.Packet();
	return packet->mc = value;
    case "data":
	if (!packet) packet = PSYC.Packet();
	packet->data = dsig->encode(value);
	return value;
    case "packet":
	return packet = value;
    case "vars":
	if (!packet) packet = PSYC.Packet();
	packet->vars = vsig->encode(value);

	vars = vsig->decode(packet->vars)+([]);

	if (!bridge) {
	    bridge = Bridge();
	}

	return bridge;
    }

    return ::`->(index); //this[index];
}

mixed `->(string index) {

    switch (index) {
    case "source":
	if (!mmp_packet) return UNDEFINED;
	return mmp_packet->source;
    case "target":
	if (!mmp_packet) return UNDEFINED;
	return mmp_packet->target;
    case "mc":
	if (!packet) return UNDEFINED;
	return packet->mc;
    case "data":
	if (!packet) return UNDEFINED;
	return dsig->decode(packet->data);
    case "vars":
	if (!vars) {
	    if (!packet) return UNDEFINED;
	    vars = vsig->decode(packet->vars)+([]);
	    bridge = Bridge();
	}

	return bridge;
    }

    return ::`->(index); //this[index];
}

Iterator _get_iterator() {
    return BridgeIterator();
}

mixed `[](mixed key) {
    return this->vars[key];
}

// TODO: do assign here by default
mixed `[]=(mixed key, mixed val) {
    return this->vars[key] = val;
}

void change_state(Serialization.Atom a) {
    snapshot->parent->apply(a, id);
}
                                                          
                             //\
                            // \\
                           //   \\
                          //     \\
                         //       \\
                        //         \\
                       //           \\
                      //             \\
                     //               \\
                    //                 \\
                   //                   \\
                  //                     \\
                 //                       \\
                //                         \\
               //                           \\
              //                             \\
             //_______________________________\\
            //_________________________________\\
           //                                   \\
          //                                     \\
         //                                       \\
        //                                         \\
       //                                           \\
      //                                             \\
     //                                               \\
    //                                                 \\
   //                                                   \\
  // ads key->val to state and adds a state change entry \\
 // to the psyc-packet if necessary (i.e. if the state    \\
// was different before)                                   \\
void assign(mixed key, mixed val) {
    if (state[key] != val) {
	Serialization.Atom a = vsig->encode(([ key : val ]));
	a->action = "_add";
	change_state(a);
    }
}

