var flagDebugMode = flag.Bool("test.sqldebug", false, "Turns on debug mode for SQL statements")
var flagConfigFile = flag.String("test.config", "", "Overrides the default config")

var (
	dbMain tester
)

type tester interface {
	setup() error
	conn() (*sql.DB, error)
	teardown() error
}

func TestMain(m *testing.M) {
	if dbMain == nil {
		fmt.Println("no dbMain tester interface was ready")
		os.Exit(-1)
	}

	rand.Seed(time.Now().UnixNano())

	flag.Parse()

	var err error

	// Load configuration
	err = initViper()
	if err != nil {
		fmt.Println("unable to load config file")
		os.Exit(-2)
	}

	if err := validateConfig("{{.DriverName}}"); err != nil {
		fmt.Println("failed to validate config", err)
		os.Exit(-3)
	}

	// Set DebugMode so we can see generated sql statements
	boil.DebugMode = *flagDebugMode

	if err = dbMain.setup(); err != nil {
		fmt.Println("Unable to execute setup:", err)
		os.Exit(-4)
	}

  conn, err := dbMain.conn()
  if err != nil {
    fmt.Println("failed to get connection:", err)
  }

	var code int
	boil.SetDB(conn)
	code = m.Run()

	if err = dbMain.teardown(); err != nil {
		fmt.Println("Unable to execute teardown:", err)
		os.Exit(-5)
	}

	os.Exit(code)
}

func initViper() error {
 	if flagConfigFile != nil && *flagConfigFile != "" {
		viper.SetConfigFile(*flagConfigFile)
		if err := viper.ReadInConfig(); err != nil {
			return err
		}
		return nil
	}

  var err error

	viper.SetConfigName("sqlboiler")

	configHome := os.Getenv("XDG_CONFIG_HOME")
	homePath := os.Getenv("HOME")
	wd, err := os.Getwd()
	if err != nil {
		wd = "../"
	} else {
		wd = wd + "/.."
	}

	configPaths := []string{wd}
	if len(configHome) > 0 {
		configPaths = append(configPaths, filepath.Join(configHome, "sqlboiler"))
	} else {
		configPaths = append(configPaths, filepath.Join(homePath, ".config/sqlboiler"))
	}

	for _, p := range configPaths {
		viper.AddConfigPath(p)
	}

	viper.SetDefault("psql.schema", "public")
	viper.SetDefault("psql.port", 5432)
	viper.SetDefault("psql.sslmode", "require")
	viper.SetDefault("mysql.sslmode", "true")
	viper.SetDefault("mysql.port", 3306)
	viper.SetDefault("mssql.schema", "dbo")
	viper.SetDefault("mssql.sslmode", "true")
	viper.SetDefault("mssql.port", 1433)
	viper.SetDefault("crdb.schema", "public")
	viper.SetDefault("crdb.port", 26257)
	viper.SetDefault("crdb.sslmode", "require")

	// Ignore errors here, fall back to defaults and validation to provide errs
	_ = viper.ReadInConfig()
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	viper.AutomaticEnv()

	return nil
}

func validateConfig(driverName string) error {
	if driverName == "psql" {
		return vala.BeginValidation().Validate(
			vala.StringNotEmpty(viper.GetString("psql.user"), "psql.user"),
			vala.StringNotEmpty(viper.GetString("psql.host"), "psql.host"),
			vala.Not(vala.Equals(viper.GetInt("psql.port"), 0, "psql.port")),
			vala.StringNotEmpty(viper.GetString("psql.dbname"), "psql.dbname"),
			vala.StringNotEmpty(viper.GetString("psql.sslmode"), "psql.sslmode"),
		).Check()
	}

	if driverName == "mysql" {
		return vala.BeginValidation().Validate(
			vala.StringNotEmpty(viper.GetString("mysql.user"), "mysql.user"),
			vala.StringNotEmpty(viper.GetString("mysql.host"), "mysql.host"),
			vala.Not(vala.Equals(viper.GetInt("mysql.port"), 0, "mysql.port")),
			vala.StringNotEmpty(viper.GetString("mysql.dbname"), "mysql.dbname"),
			vala.StringNotEmpty(viper.GetString("mysql.sslmode"), "mysql.sslmode"),
		).Check()
	}

	if driverName == "mssql" {
		return vala.BeginValidation().Validate(
			vala.StringNotEmpty(viper.GetString("mssql.user"), "mssql.user"),
			vala.StringNotEmpty(viper.GetString("mssql.host"), "mssql.host"),
			vala.Not(vala.Equals(viper.GetInt("mssql.port"), 0, "mssql.port")),
			vala.StringNotEmpty(viper.GetString("mssql.dbname"), "mssql.dbname"),
			vala.StringNotEmpty(viper.GetString("mssql.sslmode"), "mssql.sslmode"),
		).Check()
	}

	if driverName == "crdb" {
        return vala.BeginValidation().Validate(
            vala.StringNotEmpty(viper.GetString("crdb.user"), "crdb.user"),
            vala.StringNotEmpty(viper.GetString("crdb.host"), "crdb.host"),
            vala.Not(vala.Equals(viper.GetInt("crdb.port"), 0, "crdb.port")),
            vala.StringNotEmpty(viper.GetString("crdb.dbname"), "crdb.dbname"),
            vala.StringNotEmpty(viper.GetString("crdb.sslmode"), "crdb.sslmode"),
        ).Check()
	}

	return errors.New("not a valid driver name")
}
