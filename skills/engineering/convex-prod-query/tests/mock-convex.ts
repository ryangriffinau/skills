// Minimal stand-in for a Convex deployment's /api/query endpoint, used by the
// skill tests so they never touch a real deployment. Prints the port on stdout.
const maxBodyBytes = 64 * 1024;

type QueryBody = { args: unknown; format: string; path: string };

async function handleRequest(request: Request): Promise<Response> {
	const url = new URL(request.url);
	if (request.method !== "POST" || url.pathname !== "/api/query") {
		return new Response("not found", { status: 404 });
	}
	const declared = Number(request.headers.get("content-length") ?? "0");
	if (!Number.isFinite(declared) || declared > maxBodyBytes) {
		return new Response("payload too large", { status: 413 });
	}
	const raw = await request.text();
	if (raw.length > maxBodyBytes) {
		return new Response("payload too large", { status: 413 });
	}
	let body: QueryBody;
	try {
		body = JSON.parse(raw) as QueryBody;
	} catch {
		return new Response("invalid JSON", { status: 400 });
	}
	const auth = request.headers.get("authorization") ?? "";
	if (body.path.includes("Mutation")) {
		return Response.json({
			errorMessage: `Server Error\nTrying to execute ${body.path} as Query, but it is defined as Mutation.\n`,
			status: "error",
		});
	}
	if (body.path === "echo:args") {
		return Response.json({
			status: "success",
			value: { args: body.args, auth, format: body.format, path: body.path },
		});
	}
	return Response.json({
		errorMessage: `Server Error\nCould not find public function for '${body.path}'.\n`,
		status: "error",
	});
}

const server = Bun.serve({ fetch: handleRequest, port: 0 });
console.log(server.port);
