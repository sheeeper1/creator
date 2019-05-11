steedosCord = require('@steedos/core')
steedosCord.getObjectConfigManager().loadStandardObjects()
# Creator.Objects = steedosCord.Objects
# Creator.Reports = steedosCord.Reports
Meteor.startup ->
	try
		objectql = require("@steedos/objectql")
		steedosAuth = require("@steedos/auth")
		newObjects = {}
		objectsRolesPermission = {}
		_.each Creator.Objects, (obj, key)->
			if /^[_a-zA-Z][_a-zA-Z0-9]*$/.test(key)
				newObjects[key] = obj
			objectsRolesPermission[key] = obj.permission_set

		Creator.steedosSchema = objectql.getSteedosSchema()

		Creator.steedosSchema.addDataSource('default',{
			driver: 'meteor-mongo'
			objects: newObjects
			objectsRolesPermission: objectsRolesPermission
		})

		#### 测试代码开始 TODO:remove ####
		path =require('path')
		testRootDir = path.resolve('../../../../../test')
		console.log('testRootDir', testRootDir);
		Creator.steedosSchema.addDataSource('mall', {
			driver: "sqlite",
			url: path.join(testRootDir, 'mall.db'),
			objectFiles: [path.join(testRootDir, 'mall')]
		})

		Creator.steedosSchema.useAppFile(path.join(testRootDir, 'mall'))

		Creator.steedosSchema.getDataSource('mall').createTables()

		if Meteor.settings.datasource?.stock?.url
			Creator.steedosSchema.addDataSource('stock', {
				driver: "sqlserver",
				options: {
					tdsVersion: "7_2"
					useUTC: true
				},
				url: Meteor.settings.datasource.stock.url,
				objectFiles: [path.join(testRootDir, 'stock')]
			})

			Creator.steedosSchema.useAppFile(path.join(testRootDir, 'stock'))

			Creator.steedosSchema.getDataSource('stock').createTables()

		if Meteor.settings.datasource?.pdrq?.url
			Creator.steedosSchema.addDataSource('pdrq', {
				driver: "sqlserver",
				options: {
					tdsVersion: "7_2"
					useUTC: true
				},
				url: Meteor.settings.datasource.pdrq.url,
				objectFiles: [path.join(testRootDir, 'pdrq_contracts')]
			})

			Creator.steedosSchema.useAppFile(path.join(testRootDir, 'pdrq_contracts'))

			Creator.steedosSchema.getDataSource('pdrq').createTables()

		Creator.steedosSchema.addDataSource('mongo', {
			driver: "mongo"
			url: "mongodb://127.0.0.1/mongo",
			objectFiles: [path.join(testRootDir, 'mongo')]
		})

		Creator.steedosSchema.useAppFile(path.join(testRootDir, 'mongo'))

		Creator.steedosSchema.getDataSource('mongo').createTables()
		
		if Meteor.settings.datasource?.mattermost?.url
			Creator.steedosSchema.addDataSource('mattermost', {
				driver: "postgres",
				url: Meteor.settings.datasource.mattermost.url,
				objectFiles: [path.join(testRootDir, 'mattermost')]
			})

			Creator.steedosSchema.useAppFile(path.join(testRootDir, 'mattermost'))

			Creator.steedosSchema.getDataSource('mattermost').createTables()
		
		if Meteor.settings.datasource?.test_postgres?.url
			Creator.steedosSchema.addDataSource('test_postgres', {
				driver: "postgres",
				url: Meteor.settings.datasource.test_postgres.url,
				objectFiles: [path.join(testRootDir, 'test_postgres')]
			})

			Creator.steedosSchema.useAppFile(path.join(testRootDir, 'test_postgres'))

			Creator.steedosSchema.getDataSource('test_postgres').createTables()

		#### 测试代码结束 ####
		express = require('express');
		graphqlHTTP = require('express-graphql');
		app = express();
		router = express.Router();
		router.use((req, res, next)->
			authToken = authToken = Steedos.getAuthToken(req, res)

			user = null
			if authToken
				user = Meteor.wrapAsync((authToken, cb)->
					steedosAuth.getSession(authToken).then (resolve, reject)->
						cb(reject, resolve)
				)(authToken)

			if user
				# 因为没有spaceId,无法获取roles，暂不启用权限校验
				# req.userSession = user
				next();
			else
				res.status(401).send({ errors: [{ 'message': 'You must be logged in to do this.' }] });
		)
		_.each Creator.steedosSchema.getDataSources(), (datasource, name) ->
			router.use("/#{name}", graphqlHTTP({
				schema: datasource.buildGraphQLSchema(),
				graphiql: true
			}))

		app.use('/graphql', router);
		WebApp.connectHandlers.use(app);
	catch e
		console.error(e)