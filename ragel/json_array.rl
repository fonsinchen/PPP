// vim:syntax=ragel
%%{
    machine JSON_array;

    action parse_value {
	value = (struct svalue*)malloc(sizeof(struct svalue));
	memset(value, 0, sizeof(struct svalue));
	i = _parse_JSON(fpc, pe, value, s);

	if (i == NULL) {
	    free(value);
	    fbreak;
	}

	var->u.array = append_array(var->u.array, value);
	fexec i;
    }

    myspace = ' ';
    value_start = ["[{\-+.tf] | digit;

    main := '[' . myspace* . (
			      start: (
				']' -> final |
				value_start >parse_value . myspace* -> more
			      ),
			      more: (
				']' -> final |
				',' . myspace* -> start 
			      )
			     );
}%%

char *_parse_JSON_array(char *p, char *pe, struct svalue *var, struct string_builder *s) {
    char *i = p;
    int cs;
    struct svalue *value; 

    var->type = PIKE_T_ARRAY;
    var->u.array = low_allocate_array(0, 8);

    %% write init;
    %% write exec;

    // error
    if (cs == JSON_array_error || i == NULL) {
	do_free_array(var->u.array);
	return NULL;
    }
}
