import { defineConfig } from 'vite';
import chokidar from 'chokidar';

export default defineConfig({
	plugins: [
		{
			name: 'watch-public-folder',
			configureServer(server)
			{
				chokidar.watch('public/**/*').on('all', () =>
				{
					server.ws.send({
						type: 'full-reload',
					});
				});
			},
		},
	],
	server: {
		port: 9999,
        open: true,
		proxy: {
			'/api': 'http://localhost:9999'
		}
    },

	build: {
		target: 'es2021'
	}
});