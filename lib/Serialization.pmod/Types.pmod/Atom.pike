void create(string type) {
}

int(0..1) low_can_decode(Serialization.Atom a) {
    return 1;
}

int (0..1) low_can_encode(mixed a) {
    if (!has_index(a, "data") || !has_index(a, "type")) return 0;

    return 1;
}

int (0..1) can_encode(mixed a) {
    return low_can_encode(a);
}

int(0..1) can_decode(Serialization.Atom a) {
    return low_can_decode(a);
}

Serialization.Atom decode(Serialization.Atom a) { 
    if (!can_decode(a)) {
	error("cannot decode %O.\n", a);
    }
    return a; 
}
Serialization.Atom encode(Serialization.Atom a) { 
    if (!can_encode(a)) {
	error("cannot encode %O.\n", a);
    }
    return a;
}

string _sprintf(int type) {
    if (type == 'O') {
	return "Serialization.AnyAtom()";
    }

    return 0;
}