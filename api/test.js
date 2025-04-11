// api/test.js
export default function handler(req, res) {
	console.log("✅ /api/test 呼び出された！");
  res.status(200).json({ message: "✅ This test function is alive!" });
}
