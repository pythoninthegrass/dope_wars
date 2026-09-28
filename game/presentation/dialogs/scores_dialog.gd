class_name ScoresDialog
extends DopeDialog

## The read-only high-score table (index.html:1592-1606), opened from the
## Scores menu. Rows come straight off disk via HighscoreStore, so the date
## column is the platform's, not the core's.

func present(records: Array) -> ScoresDialog:
	setup(Copy.DLG_HIGH_SCORES)
	custom_minimum_size = Vector2(400, 0)

	var table := GridContainer.new()
	table.columns = 5
	table.add_theme_constant_override("h_separation", 12)
	body().add_child(table)

	for header_key in [Copy.LBL_NAME, Copy.LBL_SCORE, Copy.LBL_DAY, Copy.LBL_STATUS, Copy.LBL_DATE]:
		var head := Label.new()
		head.text = tr(header_key)
		head.theme_type_variation = &"TableTitle"
		table.add_child(head)

	if records.is_empty():
		var empty := Label.new()
		empty.text = tr(Copy.MSG_NO_SCORES)
		body().add_child(empty)
	else:
		for row: Dictionary in records:
			table.add_child(_cell(String(row["name"])))
			table.add_child(_cell(Copy.money(int(row["score"]))))
			table.add_child(_cell(str(int(row["day"]))))
			# index.html:1594 leaves Status blank for a clean finish.
			table.add_child(_cell(tr(Copy.STATUS_DEAD) if bool(row["dead"]) else ""))
			table.add_child(_cell(String(row.get("date", ""))))

	add_button("scoresClose", Copy.BTN_CLOSE, true)
	return self


func _cell(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"TableCell"
	return label
