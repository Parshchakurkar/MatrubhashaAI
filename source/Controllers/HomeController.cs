using Microsoft.AspNetCore.Mvc;

namespace MatrubhashaAI.Controllers
{
    public class HomeController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }

        public IActionResult About()
        {
            return View();
        }

        public IActionResult Features()
        {
            return View();
        }
    }
}
