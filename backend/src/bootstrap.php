<?php
declare(strict_types=1);

function env_value(string $key, ?string $default = null): ?string {
    $value = getenv($key);
    if ($value !== false) return $value;
    static $fileEnv = null;
    if ($fileEnv === null) {
        $fileEnv = [];
        $file = dirname(__DIR__).'/.env';
        if (is_file($file)) foreach (file($file, FILE_IGNORE_NEW_LINES|FILE_SKIP_EMPTY_LINES) as $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) continue;
            [$name, $value] = explode('=', $line, 2);
            $fileEnv[trim($name)] = trim(trim($value), "\"'");
        }
    }
    return $fileEnv[$key] ?? $default;
}
function db(): PDO {
    static $pdo = null;
    if ($pdo instanceof PDO) return $pdo;
    $dsn = sprintf('mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4', env_value('DB_HOST','127.0.0.1'), env_value('DB_PORT','3306'), env_value('DB_NAME','cineverse'));
    $pdo = new PDO($dsn, env_value('DB_USER','root'), env_value('DB_PASSWORD',''), [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC, PDO::ATTR_EMULATE_PREPARES=>false]);
    return $pdo;
}
function respond(mixed $data, int $status = 200): never {
    http_response_code($status); header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['data'=>$data], JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE); exit;
}
function fail(string $message, int $status = 400, array $details = []): never {
    http_response_code($status); header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error'=>['message'=>$message,'details'=>$details]], JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE); exit;
}
function body(): array {
    if (str_starts_with(strtolower($_SERVER['CONTENT_TYPE'] ?? ''), 'multipart/form-data')) return $_POST;
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') return $_POST;
    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) fail('Request body must be valid JSON.');
    return $decoded;
}
function input_list(array $input, string $key): array {
    $value = $input[$key] ?? [];
    if (is_string($value)) $value = json_decode($value, true);
    return is_array($value) ? $value : [];
}
function token_for(array $user): string {
    $secret = env_value('APP_KEY'); if (!$secret || strlen($secret)<32) fail('Server APP_KEY must be configured (at least 32 characters).',500);
    $head = rtrim(strtr(base64_encode(json_encode(['alg'=>'HS256','typ'=>'JWT'])),'+/','-_'),'=');
    $payload = rtrim(strtr(base64_encode(json_encode(['sub'=>(int)$user['id'],'role'=>$user['role'],'exp'=>time()+43200])),'+/','-_'),'=');
    $signature = rtrim(strtr(base64_encode(hash_hmac('sha256',"$head.$payload",$secret,true)),'+/','-_'),'=');
    return "$head.$payload.$signature";
}
function current_user(bool $required = true): ?array {
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+(.+)$/i',$header,$m)) { if($required) fail('Authentication required.',401); return null; }
    $parts=explode('.',$m[1]); if(count($parts)!==3) fail('Invalid access token.',401);
    [$head,$payload,$sig]=$parts; $expected=rtrim(strtr(base64_encode(hash_hmac('sha256',"$head.$payload",(string)env_value('APP_KEY'),true)),'+/','-_'),'=');
    if(!hash_equals($expected,$sig)) fail('Invalid access token.',401);
    $claims=json_decode(base64_decode(strtr($payload,'-_','+/')),true);
    if(!is_array($claims)||($claims['exp']??0)<time()) fail('Access token has expired.',401);
    $q=db()->prepare('SELECT id,full_name,username,email,role,status FROM users WHERE id=?');$q->execute([(int)$claims['sub']]);$user=$q->fetch();
    if(!$user||$user['status']!=='active') fail('Account is unavailable.',401);
    return $user;
}
function require_admin(): array { $u=current_user(); if($u['role']!=='admin') fail('Administrator access required.',403); return $u; }
function audit(?int $actor,string $action,string $type,?int $id=null,array $details=[]): void {
    $q=db()->prepare('INSERT INTO audit_logs(actor_user_id,action,entity_type,entity_id,details,ip_address) VALUES(?,?,?,?,?,?)');
    $q->execute([$actor,$action,$type,$id,$details?json_encode($details):null,$_SERVER['REMOTE_ADDR']??null]);
}
function upload_image(string $field, string $folder): ?string {
    if(!isset($_FILES[$field])||$_FILES[$field]['error']===UPLOAD_ERR_NO_FILE)return null;
    $f=$_FILES[$field]; if($f['error']!==UPLOAD_ERR_OK)fail('Image upload failed.');
    if($f['size']>5*1024*1024)fail('Image must be 5 MB or smaller.');
    $mime=(new finfo(FILEINFO_MIME_TYPE))->file($f['tmp_name']);$ext=['image/jpeg'=>'jpg','image/png'=>'png','image/webp'=>'webp'][$mime]??null;
    if(!$ext||!getimagesize($f['tmp_name']))fail('Only JPG, PNG, or WebP images are accepted.');
    $root=dirname(__DIR__).'/public/uploads/'.$folder;if(!is_dir($root)&&!mkdir($root,0750,true))fail('Upload storage is unavailable.',500);
    $name=bin2hex(random_bytes(18)).'.'.$ext;if(!move_uploaded_file($f['tmp_name'],$root.'/'.$name))fail('Unable to store uploaded image.',500);
    return rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''),'/').'/uploads/'.$folder.'/'.$name;
}
function upload_images(string $field, string $folder): array {
    if (!isset($_FILES[$field])) return [];
    $files = $_FILES[$field];
    if (!is_array($files['name'] ?? null)) $files = array_map(static fn($v)=>[$v], $files);
    $paths = [];
    foreach (($files['name'] ?? []) as $i=>$name) {
        if (($files['error'][$i] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) continue;
        foreach (['name','type','tmp_name','error','size'] as $key) $_FILES['__cineverse_item'][$key] = $files[$key][$i];
        $path = upload_image('__cineverse_item', $folder);
        if ($path !== null) $paths[] = $path;
    }
    unset($_FILES['__cineverse_item']);
    return $paths;
}
function upload_video(string $field): ?array {
    if (!isset($_FILES[$field]) || $_FILES[$field]['error'] === UPLOAD_ERR_NO_FILE) return null;
    $file = $_FILES[$field];
    if ($file['error'] !== UPLOAD_ERR_OK) fail('Video upload failed. Check the PHP upload size limit.');
    if ($file['size'] > 1024*1024*1024) fail('Video must be 1 GB or smaller.');
    $mime = (new finfo(FILEINFO_MIME_TYPE))->file($file['tmp_name']);
    $extensions = ['video/mp4'=>'mp4','video/webm'=>'webm'];
    if (!isset($extensions[$mime])) fail('Movie video must be MP4 or WebM.');
    $root = dirname(__DIR__).'/storage/videos';
    if (!is_dir($root) && !mkdir($root,0750,true)) fail('Video storage is unavailable.',500);
    $name = bin2hex(random_bytes(24)).'.'.$extensions[$mime];
    if (!move_uploaded_file($file['tmp_name'],$root.'/'.$name)) fail('Unable to store uploaded video.',500);
    return ['path'=>$name,'mime'=>$mime];
}
function media_token(int $userId, int $movieId): string {
    $secret=(string)env_value('APP_KEY');$payload=rtrim(strtr(base64_encode(json_encode(['sub'=>$userId,'movie'=>$movieId,'purpose'=>'movie-media','exp'=>time()+600])),'+/','-_'),'=');
    $signature=rtrim(strtr(base64_encode(hash_hmac('sha256',$payload,$secret,true)),'+/','-_'),'=');return $payload.'.'.$signature;
}
function verify_media_token(string $token, int $movieId): array {
    $parts=explode('.',$token);if(count($parts)!==2)fail('A valid media token is required.',401);[$payload,$signature]=$parts;
    $expected=rtrim(strtr(base64_encode(hash_hmac('sha256',$payload,(string)env_value('APP_KEY'),true)),'+/','-_'),'=');if(!hash_equals($expected,$signature))fail('Invalid media token.',401);
    $claims=json_decode(base64_decode(strtr($payload,'-_','+/')),true);if(!is_array($claims)||($claims['exp']??0)<time()||($claims['purpose']??'')!=='movie-media'||(int)($claims['movie']??0)!==$movieId)fail('Media token expired or does not match this movie.',401);
    $q=db()->prepare('SELECT role,status FROM users WHERE id=?');$q->execute([(int)$claims['sub']]);$user=$q->fetch();if(!$user||$user['status']!=='active')fail('Account is unavailable.',401);
    if($user['role']!=='admin'){$q=db()->prepare('SELECT id FROM subscriptions WHERE user_id=? AND status="active" AND (expiry_date IS NULL OR expiry_date>=CURDATE()) LIMIT 1');$q->execute([(int)$claims['sub']]);if(!$q->fetch())fail('An active subscription is required to watch or download movies.',403);}
    return $claims;
}
function serve_movie_video(int $movieId, bool $download): never {
    verify_media_token((string)($_GET['token']??''),$movieId);
    $q=db()->prepare('SELECT title,video_path,video_mime FROM movies WHERE id=? AND publication_status="published" AND availability="available"');$q->execute([$movieId]);$movie=$q->fetch();if(!$movie||!$movie['video_path'])fail('Movie video is unavailable.',404);
    $path=dirname(__DIR__).'/storage/videos/'.basename($movie['video_path']);if(!is_file($path))fail('Movie video file is missing.',404);$size=filesize($path);$start=0;$end=$size-1;
    header('Content-Type: '.($movie['video_mime']?:'application/octet-stream'));header('X-Content-Type-Options: nosniff');header('Accept-Ranges: bytes');
    if($download){$name=preg_replace('/[^a-zA-Z0-9._-]+/','-',pathinfo($movie['title'],PATHINFO_FILENAME)).'.'.pathinfo($path,PATHINFO_EXTENSION);header('Content-Disposition: attachment; filename="'.$name.'"');}
    else header('Content-Disposition: inline');
    if(isset($_SERVER['HTTP_RANGE'])&&preg_match('/bytes=(\d*)-(\d*)/',$_SERVER['HTTP_RANGE'],$m)){$start=$m[1]===''?max(0,$size-(int)$m[2]):(int)$m[1];$end=$m[2]===''?$end:min($end,(int)$m[2]);if($start>$end||$start>=$size){http_response_code(416);header("Content-Range: bytes */$size");exit;}http_response_code(206);header("Content-Range: bytes $start-$end/$size");}
    header('Content-Length: '.($end-$start+1));$handle=fopen($path,'rb');if($handle===false)fail('Unable to open movie video.',500);fseek($handle,$start);while(!feof($handle)&&ftell($handle)<=$end){$remaining=$end-ftell($handle)+1;echo fread($handle,min(1024*1024,$remaining));flush();}fclose($handle);exit;
}
