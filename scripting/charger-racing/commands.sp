enum struct Command {
	char command[64];
	char description[64];
	int adminFlags;

	void Set(const char[] command, const char[] description, int adminFlags) {
		strcopy(this.command, sizeof(Command::command), command);
		strcopy(this.description, sizeof(Command::description), description);
		this.adminFlags = adminFlags;
	}
}