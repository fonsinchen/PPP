inherit Serialization.Types.Int;

void create() {
	::create();
	type = "_time";
}

Serialization.Atom encode(mixed o) {
	return ::encode(o->unix_time());
}

Calendar.TimeRange decode(Serialization.Atom atom) {
	return Calendar.Second("unix", ::decode(atom));
}

int(0..1) can_encode(mixed o) {
	return intp(o) || Program.inherits(object_program(o), Calendar.TimeRange);
}