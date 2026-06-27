import { useState, useEffect } from "react";
import { Link, useLocation } from "wouter";
import { Menu, X, PlaneTakeoff } from "lucide-react";
import { Button } from "@/components/ui/button";

export function Navbar() {
  const [location] = useLocation();
  const [isScrolled, setIsScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);
    };
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const navLinks = [
    { name: "Home", path: "/" },
    { name: "About", path: "/about" },
    { name: "Platform", path: "/platform" },
    { name: "Academy", path: "/academy" },
    { name: "Contact", path: "/contact" },
  ];

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        isScrolled || mobileMenuOpen
          ? "bg-white shadow-sm border-b border-border py-4"
          : "bg-transparent py-6"
      }`}
    >
      <div className="container mx-auto px-4 md:px-6">
        <div className="flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 z-50">
            <PlaneTakeoff className={`h-8 w-8 ${isScrolled || mobileMenuOpen ? "text-primary" : "text-white"}`} />
            <span
              className={`font-bold text-xl tracking-tight transition-colors ${
                isScrolled || mobileMenuOpen ? "text-primary" : "text-white"
              }`}
            >
              Aviation Matrix 360
            </span>
          </Link>

          {/* Desktop Nav */}
          <nav className="hidden md:flex items-center gap-8">
            {navLinks.map((link) => (
              <Link
                key={link.path}
                href={link.path}
                className={`text-sm font-medium transition-colors hover:text-secondary ${
                  location === link.path
                    ? isScrolled ? "text-secondary" : "text-white"
                    : isScrolled
                    ? "text-foreground"
                    : "text-white/90"
                }`}
              >
                {link.name}
              </Link>
            ))}
          </nav>

          {/* Mobile Menu Toggle */}
          <button
            className="md:hidden z-50"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            aria-label="Toggle menu"
          >
            {mobileMenuOpen ? (
              <X className="h-6 w-6 text-foreground" />
            ) : (
              <Menu className={`h-6 w-6 ${isScrolled ? "text-foreground" : "text-white"}`} />
            )}
          </button>
        </div>

        {/* Mobile Nav */}
        {mobileMenuOpen && (
          <div className="md:hidden absolute top-full left-0 right-0 bg-white border-b border-border shadow-lg py-4 px-4 flex flex-col gap-4">
            {navLinks.map((link) => (
              <Link
                key={link.path}
                href={link.path}
                className={`text-base font-medium py-2 border-b border-border/50 ${
                  location === link.path ? "text-secondary" : "text-foreground"
                }`}
                onClick={() => setMobileMenuOpen(false)}
              >
                {link.name}
              </Link>
            ))}
          </div>
        )}
      </div>
    </header>
  );
}
