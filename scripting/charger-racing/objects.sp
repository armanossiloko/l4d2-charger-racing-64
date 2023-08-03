enum struct Object {
	char class[64];
	float origin[3];
	float angles[3];
	char model[PLATFORM_MAX_PATH];
	int skin;

	int entity;

	void Set(const char[] class, float origin[3], float angles[3], const char[] model, int skin) {
		strcopy(this.class, sizeof(Object::class), class);
		this.origin[0] = origin[0];
		this.origin[1] = origin[1];
		this.origin[2] = origin[2];
		this.angles[0] = angles[0];
		this.angles[1] = angles[1];
		this.angles[2] = angles[2];
		strcopy(this.model, sizeof(Object::model), model);
		this.skin = skin;
	}

	void Save(const char[] file, const char[] track, int index) {
		KeyValues kv = new KeyValues("racing-tracks");

		kv.ImportFromFile(file);
		kv.JumpToKey(track);
		kv.JumpToKey("track-objects", true);
		
		char sIndex[16];
		IntToString(index, sIndex, sizeof(sIndex));
		kv.JumpToKey(sIndex, true);
		
		kv.SetString("class", this.class);
		kv.SetVector("origin", this.origin);
		kv.SetVector("angles", this.angles);
		kv.SetString("model", this.model);
		kv.SetNum("skin", this.skin);

		kv.Rewind();
		kv.ExportToFile(file);

		delete kv;
	}

	void Remove(const char[] file, const char[] track, int index) {
		KeyValues kv = new KeyValues("racing-tracks");

		kv.ImportFromFile(file);
		kv.JumpToKey(track);
		kv.JumpToKey("track-objects", true);
		
		char sIndex[16];
		IntToString(index, sIndex, sizeof(sIndex));
		kv.DeleteKey(sIndex);

		kv.Rewind();
		kv.ExportToFile(file);

		delete kv;
	}

	bool IsSurvivor() {
		return StrEqual(this.class, "info_l4d1_survivor_spawn", false);
	}

	void SetClass(const char[] class) {
		this.Delete();
		strcopy(this.class, sizeof(Object::class), class);
		this.Spawn();
	}

	void SetOrigin(float origin[3]) {
		this.origin[0] = origin[0];
		this.origin[1] = origin[1];
		this.origin[2] = origin[2];
		this.Spawn();
	}

	void GetAngles(float angles[3]) {
		angles[0] = this.angles[0];
		angles[1] = this.angles[1];
		angles[2] = this.angles[2];
	}

	void SetAngles(float angles[3]) {
		this.angles[0] = angles[0];
		this.angles[1] = angles[1];
		this.angles[2] = angles[2];
		this.Spawn();
	}

	void SetModel(const char[] model) {
		strcopy(this.model, sizeof(Object::model), model);
		this.Spawn();
	}

	void SetSkin(int skin) {
		this.skin = skin;
		this.Spawn();
	}
	
	void Spawn() {
		this.Delete();

		if (StrEqual(this.class, "info_l4d1_survivor_spawn")) {
			this.entity = SpawnSurvivor(this.origin, this.angles, this.skin);
			return;
		}

		this.entity = CreateEntityByName(this.class);

		if (!IsValidEntity(this.entity)) {
			return;
		}

		DispatchKeyValueVector(this.entity, "origin", this.origin);
		DispatchKeyValueVector(this.entity, "angles", this.angles);
		DispatchKeyValue(this.entity, "model", this.model);
		DispatchKeyValueInt(this.entity, "skin", this.skin);
		DispatchSpawn(this.entity);
	}

	void Delete() {
		if (this.entity > 0 && IsValidEntity(this.entity)) {
			if (StrEqual(this.class, "info_l4d1_survivor_spawn")) {
				KickClient(this.entity);
			} else {
				RemoveEntity(this.entity);
			}
		}

		this.entity = -1;
	}

	void Clear() {
		this.class[0] = '\0';
		this.origin[0] = 0.0;
		this.origin[1] = 0.0;
		this.origin[2] = 0.0;
		this.angles[0] = 0.0;
		this.angles[1] = 0.0;
		this.angles[2] = 0.0;
		this.model[0] = '\0';
		this.skin = 0;
	}
}

enum struct ObjModel {
	char name[64];
	char path[PLATFORM_MAX_PATH];

	void Set(const char[] name, const char[] path) {
		strcopy(this.name, sizeof(ObjModel::name), name);
		strcopy(this.path, sizeof(ObjModel::path), path);
	}

	void Clear() {
		this.name[0] = '\0';
		this.path[0] = '\0';
	}
}